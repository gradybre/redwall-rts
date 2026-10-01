extends RefCounted
## The kitchen's cooked portions, as LOTS: each batch's two portions are one lot of one dish, cooked for one meal, with
## its own age. Decision 0381. Presentation only: the settlement's inventory never sees it.
##
## WHERE A LOT IS: in the POT at the kitchen as it is cooked, then AT THE TABLE once the cook has carried the pot over
## and put the portions out (`carry_out`). A diner eats only from the table, and only a lot cooked for this meal or an
## earlier one (`available`): supper's pot, carried over with breakfast's, waits under its lid until supper.
##
## EATING ORDER is §5.7's: "(expiry_age_remaining, -quality, recipe_id, lot_id)" -- the lot nearest its shelf life
## first (every portion is PLAIN, so quality never decides), then the dish, then the row. A portion is RESERVED by the
## diner who sits down to it (`reserve_one`), consumed when the eating is done (`consume_one`, REQ-SET-095: once) and
## given back if the diner is called away (`release_one`) -- never twice, never fresh.
##
## AGEING is the pantry's §5.8 rule (farm_pantry.gd SPOILAGE): each game hour `floor(store x temperature / 1000)`
## milli-hours, the fraction kept -- in the pot, the covered-store factor (the kitchen is a building, 1000); at the
## table, §5.8's "Prepared food left on tables uses open-pile factor" (1500). At 24 h a lot's unreserved portions are
## spoiled food at equal mass (a 500 g portion is 2 U of 250 g spoiled food, `spoiled_milli`). A reserved
## portion past its shelf life spoils when it is given back, not under a diner's spoon.

const Rules := preload("res://demo/kitchen/meal_rules.gd")
const StockAge := preload("res://scripts/core/stock_age.gd")

const MAX_LOTS: int = 24
const FREE: int = -1
const FACTOR_DENOMINATOR: int = 1000
const POT_PERMILLE: int = StockAge.STORE_FACTOR[StockAge.STORAGE_COVERED_STORE]
const TABLE_PERMILLE: int = StockAge.STORE_FACTOR[StockAge.STORAGE_OPEN_PILE]

var _dish: PackedInt32Array = PackedInt32Array()
var _count: PackedInt32Array = PackedInt32Array()
var _reserved: PackedInt32Array = PackedInt32Array()
var _meal: PackedInt32Array = PackedInt32Array()
var _out: PackedByteArray = PackedByteArray()
var _age: PackedInt64Array = PackedInt64Array()
var _remainder: PackedInt32Array = PackedInt32Array()
## Portions spoiled so far, as spoiled food's milli-U (taken by the kitchen into the pantry's spoiled food), and how
## many portions have ever spoiled (the checks' tally).
var spoiled_milli: int = 0
var spoiled_portions: int = 0
## Bumped on every change (the view and the panels redraw on it).
var revision: int = 0


func _init() -> void:
	"""An empty store of MAX_LOTS rows."""
	for column: PackedInt32Array in [_dish, _count, _reserved, _meal, _remainder]:
		column.resize(MAX_LOTS)
	_dish.fill(FREE)
	_out.resize(MAX_LOTS)
	_age.resize(MAX_LOTS)


func add(dish: int, portion_count: int, meal_key: int) -> int:
	"""A finished batch: `portion_count` of `dish` cooked for meal `meal_key`, fresh, in the pot. Its row (FREE: no row
	free, and nothing is added -- the kitchen never cooks a batch it cannot keep)."""
	var lot: int = _dish.find(FREE)
	if lot < 0 or portion_count <= 0:
		return FREE
	_dish[lot] = dish
	_count[lot] = portion_count
	_reserved[lot] = 0
	_meal[lot] = meal_key
	_out[lot] = 0
	_age[lot] = 0
	_remainder[lot] = 0
	revision += 1
	return lot


func has_room() -> bool:
	"""Whether a batch could be kept."""
	return _dish.find(FREE) >= 0


func in_pot(up_to_meal: int = 1 << 30) -> int:
	"""Portions cooked and not yet carried out (only those for meals up to `up_to_meal`, given one)."""
	var total: int = 0
	for lot: int in MAX_LOTS:
		if _dish[lot] != FREE and _out[lot] == 0 and _meal[lot] <= up_to_meal:
			total += _count[lot]
	return total


func carry_out() -> int:
	"""The pot carried to the table: every lot in it is put out. How many portions."""
	var moved: int = 0
	for lot: int in MAX_LOTS:
		if _dish[lot] != FREE and _out[lot] == 0:
			_out[lot] = 1
			moved += _count[lot]
	if moved > 0:
		revision += 1
	return moved


func available(meal_key: int) -> int:
	"""Portions at the table a diner of meal `meal_key` may take now (cooked for it or before, not reserved)."""
	var total: int = 0
	for lot: int in MAX_LOTS:
		if _offered(lot, meal_key):
			total += _count[lot] - _reserved[lot]
	return total


func out_for(meal_key: int) -> int:
	"""Unreserved portions at the table cooked for meal `meal_key` itself (not leftovers)."""
	var total: int = 0
	for lot: int in MAX_LOTS:
		if _dish[lot] != FREE and _out[lot] == 1 and _meal[lot] == meal_key:
			total += _count[lot] - _reserved[lot]
	return total


func _offered(lot: int, meal_key: int) -> bool:
	"""Whether lot `lot` has a portion at the table for meal `meal_key`."""
	return _dish[lot] != FREE and _out[lot] == 1 and _meal[lot] <= meal_key and _count[lot] > _reserved[lot]


func reserve_one(meal_key: int, exact: bool = false) -> int:
	"""Reserve the next portion by §5.7's order (see EATING ORDER) for a diner of meal `meal_key` -- with `exact`, only
	one cooked for that meal itself (the cook eating supper early leaves breakfast's for breakfast); its row, or FREE."""
	var best: int = FREE
	for lot: int in MAX_LOTS:
		if not _offered(lot, meal_key) or (exact and _meal[lot] != meal_key):
			continue
		if best == FREE or _before(lot, best):
			best = lot
	if best != FREE:
		_reserved[best] += 1
		revision += 1
	return best


func _before(a: int, b: int) -> bool:
	"""Whether lot `a` is eaten before lot `b`: less shelf life left, then the dish, then the row."""
	if _age[a] != _age[b]:
		return _age[a] > _age[b]
	if _dish[a] != _dish[b]:
		return _dish[a] < _dish[b]
	return a < b


func release_one(lot: int) -> void:
	"""A diner called away gives its portion back (spoiling it then if it is past its shelf life)."""
	if not _is_lot(lot) or _reserved[lot] <= 0:
		return
	_reserved[lot] -= 1
	revision += 1
	if _age[lot] >= _shelf(lot):
		_spoil_unreserved(lot)


func consume_one(lot: int) -> int:
	"""A reserved portion eaten: gone from the lot. The dish eaten (Rules.NO_DISH when `lot` holds no reservation)."""
	if not _is_lot(lot) or _reserved[lot] <= 0:
		return Rules.NO_DISH
	var dish: int = _dish[lot]
	_reserved[lot] -= 1
	_count[lot] -= 1
	if _count[lot] == 0:
		_dish[lot] = FREE
	revision += 1
	return dish


func _is_lot(lot: int) -> bool:
	"""Whether `lot` is a live row."""
	return lot >= 0 and lot < MAX_LOTS and _dish[lot] != FREE


func _shelf(lot: int) -> int:
	"""A lot's shelf life in milli-hours."""
	return Rules.SHELF_HOURS[_dish[lot]] * FACTOR_DENOMINATOR


func age_hour(season: int) -> int:
	"""Age every lot a game hour in `season` (see AGEING); returns the portions that spoiled."""
	var temperature: int = StockAge.temperature_factor_of(season, false)
	var spoiled: int = 0
	for lot: int in MAX_LOTS:
		if _dish[lot] == FREE:
			continue
		var numerator: int = (TABLE_PERMILLE if _out[lot] == 1 else POT_PERMILLE) * temperature + _remainder[lot]
		@warning_ignore("integer_division") _age[lot] += numerator / FACTOR_DENOMINATOR
		_remainder[lot] = numerator % FACTOR_DENOMINATOR
		if _age[lot] >= _shelf(lot):
			spoiled += _spoil_unreserved(lot)
	return spoiled


func _spoil_unreserved(lot: int) -> int:
	"""The lot's unreserved portions become spoiled food at equal mass; returns how many."""
	var gone: int = _count[lot] - _reserved[lot]
	if gone <= 0:
		return 0
	_count[lot] -= gone
	spoiled_portions += gone
	@warning_ignore("integer_division") spoiled_milli += gone * Rules.MILLI_PER_U * Rules.PORTION_G / Rules.SPOILED_G
	if _count[lot] == 0:
		_dish[lot] = FREE
	revision += 1
	return gone


func take_spoiled() -> int:
	"""Hand over the spoiled food's milli-U made so far (the pantry's spoiled food takes it)."""
	var taken: int = spoiled_milli
	spoiled_milli = 0
	return taken


# --- readouts ----------------------------------------------------------------------------------

func portions() -> int:
	"""Every portion held, in the pot or at the table."""
	var total: int = 0
	for lot: int in MAX_LOTS:
		if _dish[lot] != FREE:
			total += _count[lot]
	return total


func portions_lasting(meal_key: int, hours: int, season: int) -> int:
	"""Portions cooked for meals before `meal_key` (the leftovers, when it is the first meal still to be served) that
	will still be good `hours` game hours from now, ageing where they are at `season`'s temperature (see AGEING)."""
	var total: int = 0
	var temperature: int = StockAge.temperature_factor_of(season, false)
	for lot: int in MAX_LOTS:
		if _dish[lot] == FREE or _meal[lot] >= meal_key:
			continue
		@warning_ignore("integer_division") var rate: int = (TABLE_PERMILLE if _out[lot] == 1 else POT_PERMILLE) * temperature / FACTOR_DENOMINATOR
		if _shelf(lot) - int(_age[lot]) > hours * rate:
			total += _count[lot]
	return total


func portions_of(dish: int) -> int:
	"""Portions of `dish` held."""
	var total: int = 0
	for lot: int in MAX_LOTS:
		if _dish[lot] == dish:
			total += _count[lot]
	return total


func at_table() -> int:
	"""Portions put out at the table."""
	return portions() - in_pot()


func hours_left_of(dish: int, season: int) -> int:
	"""Game hours until `dish`'s first lot spoils where it is, at `season`'s temperature (-1: none held) -- the lot
	with least left at its own rate (see AGEING)."""
	var least: int = -1
	var temperature: int = StockAge.temperature_factor_of(season, false)
	for lot: int in MAX_LOTS:
		if _dish[lot] != dish:
			continue
		@warning_ignore("integer_division") var rate: int = maxi(1, (TABLE_PERMILLE if _out[lot] == 1 else POT_PERMILLE) * temperature / FACTOR_DENOMINATOR)
		@warning_ignore("integer_division") var left: int = (_shelf(lot) - int(_age[lot]) + rate - 1) / rate
		least = left if least < 0 else mini(least, left)
	return least


func lot_count(lot: int) -> int:
	"""Portions in lot `lot` (0 for a free row)."""
	return _count[lot] if _is_lot(lot) else 0


func lot_reserved(lot: int) -> int:
	"""Portions of lot `lot` reserved by diners."""
	return _reserved[lot] if _is_lot(lot) else 0


func lot_dish(lot: int) -> int:
	"""Lot `lot`'s dish (FREE: a free row)."""
	return _dish[lot]


func lot_age(lot: int) -> int:
	"""Lot `lot`'s effective age in milli-hours (tests)."""
	return int(_age[lot])


func lot_out(lot: int) -> bool:
	"""Whether lot `lot` is at the table."""
	return _is_lot(lot) and _out[lot] == 1
