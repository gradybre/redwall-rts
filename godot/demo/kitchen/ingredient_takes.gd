extends RefCounted
## The kitchen's RESERVATIONS on the pantry's food: which lots a planned meal will cook from, and how far each has got.
## Decision 0381, after decision 0222's holds (a harvest reserves its room before it is cut). Presentation only.
##
## RESERVE, CONSUME, RETURN. A planned meal TAKES (reserves) the food its batches need, from real lots, the one that
## spoils first first (`lot_spoil_hours`, the very forecast the Pantry prints; GDD §5.7: "Mixed ingredient categories
## bind concrete lots at reservation time and preserve that selection through completion"). The food stays IN ITS LOT
## -- in its store's books, ageing at its store's rate, counted in its store -- until a batch starts: then exactly the
## batch's milli-U are withdrawn from those lots (`consume_into`, farm_pantry.gd `withdraw_into`), once. A take given up
## (a cancel, a smaller meal) simply stops reserving (`release`): nothing moved, so nothing is credited back and no lot
## is made fresher. So there is no second debit and no second credit to get wrong.
##
## AN ENTRY is (take, lot row, the lot's serial, milli-U, where it is). The SERIAL (farm_pantry.gd WITHDRAWALS) makes a
## lot that spoiled and whose row was reused by another lot no longer this entry's: the entry then counts for nothing
## (`live_milli`) and is dropped (`prune`), and the meal is short by it -- spoiled food is never cooked.
##
## WHERE THE FOOD IS, for the cook's walks: AT_STORE (reserved in its store), IN_HAND (the cook picked it up and is
## carrying it) or AT_KITCHEN (put down by the cauldron). The books do not move with it: the Pantry shows it in its
## store, "with the cook" (`with_cook_milli`).
##
## Other eaters respect the takes: `free_milli` is a lot's milli-U less what is reserved in it (the raw emergency food
## a hungry resident may eat; REQ-SET-013: "nonreserved").
##
## A SELECTOR says which pantry items a reservation may hold (decision 0601): a CATEGORY (farm_catalog.gd category_of: a
## §5.6 crop row or a goods category -- §5.7's input), or SELECT_ITEMS plus a mask of item rows (bit n: item n) -- a
## dish's own ingredients within its category (dish_book.gd); ANY (-1) takes every item. `matches` decides, with no
## allocation; every parameter named `crop` below is a selector.

const Catalog := preload("res://demo/farm/farm_catalog.gd")
const PantryScript := preload("res://demo/farm/farm_pantry.gd")
const IntMath := preload("res://scripts/core/int_math.gd")

const MAX_ENTRIES: int = 96
const FREE: int = -1
const AT_STORE: int = 0
const IN_HAND: int = 1
const AT_KITCHEN: int = 2
const REFUSE_SHORT: String = "NOT_ENOUGH_RESERVED"
const ANY: int = -1
## A selector with this bit set is an item mask; the pantry's 24 item rows fit beneath it (test_demo_dishes.gd checks).
const SELECT_ITEMS: int = 1 << 30
const MASK_BITS: int = 30

var _take: PackedInt32Array = PackedInt32Array()
var _lot: PackedInt32Array = PackedInt32Array()
var _serial: PackedInt32Array = PackedInt32Array()
var _milli: PackedInt64Array = PackedInt64Array()
var _where: PackedByteArray = PackedByteArray()
var _next_take: int = 1
var _read: IntMath.IntResult = IntMath.IntResult.new()
## `reserve_into`'s candidate rows and their spoil hours (reused).
var _rows: PackedInt32Array = PackedInt32Array()
var _hours: PackedInt32Array = PackedInt32Array()
## Milli-U per pantry lot row, summed in one pass over the entries (reused): what every take reserves in each lot
## (`free_milli_of_crop`), or what one take would withdraw from each (`consume_into`'s all-or-nothing check).
var _per_lot: PackedInt64Array = PackedInt64Array()


func _init() -> void:
	"""An empty table of MAX_ENTRIES rows."""
	for column: PackedInt32Array in [_take, _lot, _serial]:
		column.resize(MAX_ENTRIES)
	_per_lot.resize(PantryScript.MAX_LOTS)
	_take.fill(FREE)
	_milli.resize(MAX_ENTRIES)
	_where.resize(MAX_ENTRIES)


static func matches(selector: int, item: int) -> bool:
	"""Whether pantry `item` is one selector `selector` takes (see A SELECTOR); never for no item."""
	if item < 0:
		return false
	if selector < 0:
		return true
	if (selector & SELECT_ITEMS) != 0:
		return item < MASK_BITS and ((selector >> item) & 1) == 1
	return Catalog.category_of(item) == selector


static func items_selector(items: PackedInt32Array) -> int:
	"""The selector taking exactly these item rows (each below MASK_BITS)."""
	var selector: int = SELECT_ITEMS
	for item: int in items:
		selector |= 1 << item
	return selector


func new_take() -> int:
	"""A fresh take id (nothing reserved under it yet)."""
	_next_take += 1
	return _next_take


func reserved_in(lot: int, serial: int) -> int:
	"""How much of the lot opened with `serial` in row `lot` every take reserves, milli-U."""
	var held: int = 0
	for e: int in MAX_ENTRIES:
		if _take[e] != FREE and _lot[e] == lot and _serial[e] == serial:
			held += _milli[e]
	return held


func free_milli(pantry: PantryScript, lot: int) -> int:
	"""A live lot's milli-U nobody has reserved (0 for a free row)."""
	var serial: int = pantry.lot_serial(lot)
	if serial == 0:
		return 0
	return maxi(0, pantry.lot_milli(lot) - reserved_in(lot, serial))


func free_milli_of_crop(pantry: PantryScript, crop: int) -> int:
	"""Unreserved milli-U of every item selector `crop` takes in the pantry (one pass over the entries, one over the
	lots)."""
	_sum_per_lot(pantry, FREE, -1)
	var total: int = 0
	for lot: int in PantryScript.MAX_LOTS:
		var item: int = pantry.lot_item(lot)
		if item != PantryScript.FREE and matches(crop, item):
			total += maxi(0, pantry.lot_milli(lot) - _per_lot[lot])
	return total


func _sum_per_lot(pantry: PantryScript, take: int, where: int) -> void:
	"""Fill `_per_lot` with the live entries' milli-U by lot row: every take's (`take` FREE), or `take`'s at `where`."""
	_per_lot.fill(0)
	for e: int in MAX_ENTRIES:
		if _take[e] == FREE or (take != FREE and (_take[e] != take or _where[e] != where)) or not _live(pantry, e):
			continue
		_per_lot[_lot[e]] += _milli[e]


func reserve_into(pantry: PantryScript, take: int, crop: int, milli: int, hour_index: int,
		out: IntMath.IntResult) -> bool:
	"""Reserve up to `milli` of selector `crop`'s food under `take`, the lot that spoils first first (see RESERVE).
	How much was reserved into `out` (0 when there was none, or no entry row was free); refuses a bad quantity."""
	if milli <= 0:
		return out.refuse(PantryScript.REFUSE_BAD_QUANTITY)
	_candidates(pantry, crop, hour_index)
	var left: int = milli
	while left > 0:
		var k: int = _soonest()
		if k < 0:
			break
		var lot: int = _rows[k]
		_rows[k] = FREE
		var part: int = mini(left, free_milli(pantry, lot))
		if part > 0 and _add_entry(take, lot, pantry.lot_serial(lot), part):
			left -= part
	return out.succeed(milli - left)


func reserve_lot(pantry: PantryScript, take: int, lot: int, milli: int) -> int:
	"""Reserve up to `milli` of lot `lot`'s unreserved food under `take` (a raw emergency meal); how much."""
	var part: int = mini(milli, free_milli(pantry, lot))
	if part <= 0 or not _add_entry(take, lot, pantry.lot_serial(lot), part):
		return 0
	return part


func _candidates(pantry: PantryScript, crop: int, hour_index: int) -> void:
	"""Every live lot selector `crop` takes with unreserved food, and its spoil hours, into the scratch arrays."""
	_rows.clear()
	_hours.clear()
	for lot: int in PantryScript.MAX_LOTS:
		var item: int = pantry.lot_item(lot)
		if item == PantryScript.FREE or not matches(crop, item) or free_milli(pantry, lot) <= 0:
			continue
		_rows.append(lot)
		_hours.append(pantry.lot_spoil_hours(lot, hour_index))


func _soonest() -> int:
	"""The candidate that spoils first (the lowest row on a tie); -1 when none is left."""
	var best: int = -1
	for k: int in _rows.size():
		if _rows[k] == FREE:
			continue
		if best < 0 or _hours[k] < _hours[best] or (_hours[k] == _hours[best] and _rows[k] < _rows[best]):
			best = k
	return best


func _add_entry(take: int, lot: int, serial: int, milli: int) -> bool:
	"""A new AT_STORE entry; false when the table is full."""
	var e: int = _take.find(FREE)
	if e < 0:
		return false
	_take[e] = take
	_lot[e] = lot
	_serial[e] = serial
	_milli[e] = milli
	_where[e] = AT_STORE
	return true


func _live(pantry: PantryScript, e: int) -> bool:
	"""Whether entry `e` is held and its lot is still the one it reserved."""
	return _take[e] != FREE and pantry.lot_serial(_lot[e]) == _serial[e]


func live_milli(pantry: PantryScript, take: int, where: int = -1, crop: int = -1) -> int:
	"""How much `take` holds in lots that are still its own (only at `where`, AT_* ; -1: anywhere; only of category
	selector `crop`, -1: any -- one input of a dish), milli-U."""
	var total: int = 0
	for e: int in MAX_ENTRIES:
		if _take[e] == take and _live(pantry, e) and (where < 0 or _where[e] == where) and _is_of(pantry, e, crop):
			total += _milli[e]
	return total


func _is_of(pantry: PantryScript, e: int, crop: int) -> bool:
	"""Whether entry `e`'s lot is one selector `crop` takes (any for -1)."""
	return crop < 0 or matches(crop, pantry.lot_item(_lot[e]))


func prune(pantry: PantryScript) -> int:
	"""Drop every entry whose lot spoiled (its row now another's or free); how many milli-U were lost to it."""
	var lost: int = 0
	for e: int in MAX_ENTRIES:
		if _take[e] != FREE and not _live(pantry, e):
			lost += _milli[e]
			_take[e] = FREE
	return lost


func consume_into(pantry: PantryScript, take: int, milli: int, where: int, hour_index: int,
		out: IntMath.IntResult, crop: int = -1) -> bool:
	"""Withdraw exactly `milli` of `take`'s food from where it is (`where`, AT_*: a batch starting takes it AT_KITCHEN,
	a raw emergency meal AT_STORE), the lot that spoils first first, all or nothing. Refuses NOT_ENOUGH_RESERVED,
	changing nothing."""
	if milli <= 0:
		return out.refuse(PantryScript.REFUSE_BAD_QUANTITY)
	_trim_to_lots(pantry, take, where)
	if live_milli(pantry, take, where, crop) < milli:
		return out.refuse(REFUSE_SHORT)
	var left: int = milli
	while left > 0:
		var e: int = _soonest_at(pantry, take, where, hour_index, crop)
		var part: int = mini(left, _milli[e])
		pantry.withdraw_into(_lot[e], _serial[e], part, _read)
		_milli[e] -= part
		left -= part
		if _milli[e] == 0:
			_take[e] = FREE
	return out.succeed(milli)


func _trim_to_lots(pantry: PantryScript, take: int, where: int) -> void:
	"""Cut `take`'s entries at `where` down to what their lots still hold (food something else took is not there to
	cook), so `consume_into`'s withdrawals can never be refused half-way: all or nothing."""
	_sum_per_lot(pantry, take, where)
	for e: int in MAX_ENTRIES:
		if _take[e] != take or _where[e] != where or not _live(pantry, e):
			continue
		var over: int = _per_lot[_lot[e]] - pantry.lot_milli(_lot[e])
		if over <= 0:
			continue
		var cut: int = mini(over, _milli[e])
		_milli[e] -= cut
		_per_lot[_lot[e]] -= cut
		if _milli[e] == 0:
			_take[e] = FREE


func _soonest_at(pantry: PantryScript, take: int, where: int, hour_index: int, crop: int = -1) -> int:
	"""`take`'s live entry at `where` (of category `crop`; -1: any) whose lot spoils first (the lowest row on a tie);
	-1: none."""
	var best: int = -1
	var best_hours: int = 0
	for e: int in MAX_ENTRIES:
		if _take[e] != take or _where[e] != where or not _live(pantry, e) or not _is_of(pantry, e, crop):
			continue
		var hours: int = pantry.lot_spoil_hours(_lot[e], hour_index)
		if best < 0 or hours < best_hours:
			best = e
			best_hours = hours
	return best


func release(take: int) -> int:
	"""Give up everything `take` reserves (see RESERVE: nothing moves back); how many milli-U were reserved."""
	var freed: int = 0
	for e: int in MAX_ENTRIES:
		if _take[e] == take:
			freed += _milli[e]
			_take[e] = FREE
	return freed


func release_at_store(pantry: PantryScript, take: int, location: int) -> int:
	"""Give up `take`'s food still waiting at store `location` (fetched food is kept); how many milli-U."""
	var freed: int = 0
	for e: int in MAX_ENTRIES:
		if _take[e] == take and _where[e] == AT_STORE and pantry.lot_location(_lot[e]) == location:
			freed += _milli[e]
			_take[e] = FREE
	return freed


func release_milli(pantry: PantryScript, take: int, milli: int, hour_index: int, crop: int = -1) -> int:
	"""Give back `milli` of `take`'s reservation (of category `crop`; -1: any) it no longer needs, the latest-spoiling
	food first (still at its store first); returns how much was given back."""
	var left: int = milli
	while left > 0:
		var e: int = _latest(pantry, take, hour_index, crop)
		if e < 0:
			break
		var part: int = mini(left, _milli[e])
		_milli[e] -= part
		left -= part
		if _milli[e] == 0:
			_take[e] = FREE
	return milli - left


func _latest(pantry: PantryScript, take: int, hour_index: int, crop: int = -1) -> int:
	"""`take`'s entry (of category `crop`; -1: any) to give back first: at its store before in hand or at the kitchen,
	then the latest to spoil."""
	var best: int = -1
	var best_hours: int = 0
	for e: int in MAX_ENTRIES:
		if _take[e] != take or (crop >= 0 and not (_live(pantry, e) and _is_of(pantry, e, crop))):
			continue
		var hours: int = pantry.lot_spoil_hours(_lot[e], hour_index) if _live(pantry, e) else 1 << 30
		if best < 0 or _where[e] < _where[best] or (_where[e] == _where[best] and hours > best_hours):
			best = e
			best_hours = hours
	return best


func store_to_fetch(pantry: PantryScript, take: int) -> int:
	"""A pantry location where `take` still has food waiting at its store (the lowest; -1: none)."""
	var best: int = -1
	for e: int in MAX_ENTRIES:
		if _take[e] == take and _where[e] == AT_STORE and _live(pantry, e):
			var at: int = pantry.lot_location(_lot[e])
			best = at if best < 0 else mini(best, at)
	return best


func pick_up(pantry: PantryScript, take: int, location: int) -> int:
	"""The cook picks up `take`'s food at `location`: those entries are IN_HAND. How many milli-U."""
	var picked: int = 0
	for e: int in MAX_ENTRIES:
		if _take[e] == take and _where[e] == AT_STORE and _live(pantry, e) and pantry.lot_location(_lot[e]) == location:
			_where[e] = IN_HAND
			picked += _milli[e]
	return picked


func put_down(take: int) -> int:
	"""The cook puts `take`'s food in hand down by the cauldron: AT_KITCHEN. How many milli-U."""
	var put: int = 0
	for e: int in MAX_ENTRIES:
		if _take[e] == take and _where[e] == IN_HAND:
			_where[e] = AT_KITCHEN
			put += _milli[e]
	return put


func first_item(pantry: PantryScript, take: int, where: int) -> int:
	"""The item of `take`'s first live entry at `where` (Catalog.NO_ITEM: none) -- what the cook is drawn carrying."""
	for e: int in MAX_ENTRIES:
		if _take[e] == take and _where[e] == where and _live(pantry, e):
			return pantry.lot_item(_lot[e])
	return Catalog.NO_ITEM


func with_cook_milli(pantry: PantryScript, item: int, location: int) -> int:
	"""How much of `item` stored at `location` is reserved for the kitchen (the Pantry's "with the cook")."""
	var total: int = 0
	for e: int in MAX_ENTRIES:
		if _take[e] != FREE and _live(pantry, e) and pantry.lot_item(_lot[e]) == item \
				and pantry.lot_location(_lot[e]) == location:
			total += _milli[e]
	return total


func keep_fetched(pantry: PantryScript, from_take: int, to_take: int) -> int:
	"""Move `from_take`'s food the cook has fetched -- in hand or at the kitchen -- to `to_take` (the kitchen's larder:
	a meal over, its food stays where it was carried). How many milli-U."""
	var moved: int = 0
	for e: int in MAX_ENTRIES:
		if _take[e] == from_take and _where[e] != AT_STORE and _live(pantry, e):
			_take[e] = to_take
			moved += _milli[e]
	return moved


func fetched_milli_of_crop(pantry: PantryScript, take: int, crop: int) -> int:
	"""How much of selector `crop`'s food `take` holds fetched (in hand or at the kitchen), milli-U."""
	var total: int = 0
	for e: int in MAX_ENTRIES:
		if _take[e] == take and _where[e] != AT_STORE and _live(pantry, e) and _is_of(pantry, e, crop):
			total += _milli[e]
	return total


func draw_fetched(pantry: PantryScript, from_take: int, to_take: int, crop: int, milli: int) -> int:
	"""Move up to `milli` of selector `crop`'s fetched food (in hand or at the kitchen) from `from_take` (the larder)
	to `to_take` (a planned meal), splitting an entry where it must. How many milli-U."""
	var left: int = milli
	for e: int in MAX_ENTRIES:
		if left == 0:
			break
		if _take[e] != from_take or _where[e] == AT_STORE or not _live(pantry, e) or not _is_of(pantry, e, crop):
			continue
		if _milli[e] <= left:
			_take[e] = to_take
			left -= _milli[e]
			continue
		var split: int = _take.find(FREE)
		if split < 0:
			break
		_take[split] = to_take
		_lot[split] = _lot[e]
		_serial[split] = _serial[e]
		_milli[split] = left
		_where[split] = _where[e]
		_milli[e] -= left
		left = 0
	return milli - left


func entries_of(take: int) -> int:
	"""How many entries `take` has (tests)."""
	var n: int = 0
	for e: int in MAX_ENTRIES:
		if _take[e] == take:
			n += 1
	return n
