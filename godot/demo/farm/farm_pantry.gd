extends RefCounted
## The demo pantry: harvested ingredients kept as lots, each item counted on its own, and aged by
## where it is kept. Decision 0196. Presentation-only -- it is not the settlement's inventory and
## the settlement's ready-food figure never sees it (farm_hud.gd shows it in the HUD's place).
##
## LOTS, not a running total, because §5.8 ages FOOD LOTS: every delivery is its own lot of one
## item, at one storage location, with its own age. Quantities are milli-U (int64); a pantry item's
## count is its whole units. Lots are packed columns sized once (MAX_LOTS); when every row is taken
## a delivery merges into the oldest lot of the same item and place, which keeps the OLDER age --
## §5.8's merge rule, so merging can never make food fresher.
##
## SPOILAGE is GDD §5.8, with its own numbers: each game hour a lot ages
## `floor(store_factor * temperature_factor / 1000)` milli-hours with the fraction retained, where
## the store factor is its location's `spoilage_permille` (farm_storage.gd: covered store 1000, a
## GDD cellar 350) and the temperature factor is scripts/core/stock_age.gd's own season table
## (spring 1000, summer 1500, autumn 1000, winter 500). At `shelf_hours * 1000` the lot is spoiled
## food at equal mass: it leaves the item's count and joins `spoiled_milli`, which the Pantry view
## can send to compost at §5.7's 4 : 2 compost recipe. Shelf hours are §5.7's by crop row
## (farm_catalog.gd).

const Catalog := preload("res://demo/farm/farm_catalog.gd")
const StorageScript := preload("res://demo/farm/farm_storage.gd")
const StockAge := preload("res://scripts/core/stock_age.gd")
const IntMath := preload("res://scripts/core/int_math.gd")

const MAX_LOTS: int = 128
const FREE: int = -1
const MILLI_PER_U: int = 1000
const FACTOR_DENOMINATOR: int = 1000
## §5.7: "compost | spoiled_food 4 ... | compost 2".
const COMPOST_FROM_SPOILED_IN: int = 4
const COMPOST_FROM_SPOILED_OUT: int = 2

const REFUSE_NOT_AN_ITEM: String = "NOT_AN_ITEM"
const REFUSE_BAD_QUANTITY: String = "INVALID_QUANTITY"
const REFUSE_NO_LOCATION: String = "NO_SUCH_LOCATION"
const REFUSE_NO_ROOM: String = "NO_STORAGE_ROOM"
const REFUSE_NO_STOCK: String = "NO_STOCK"

var storage: StorageScript = null
var spoiled_milli: int = 0

var _lot_item: PackedInt32Array = PackedInt32Array()
var _lot_location: PackedInt32Array = PackedInt32Array()
var _lot_milli: PackedInt64Array = PackedInt64Array()
var _lot_age: PackedInt64Array = PackedInt64Array()
var _lot_remainder: PackedInt32Array = PackedInt32Array()
var _item_milli: PackedInt64Array = PackedInt64Array()
var _spoiled_items: PackedInt32Array = PackedInt32Array()
var _ids: Array = []
var _read: IntMath.IntResult = IntMath.IntResult.new()


func _init(p_storage: StorageScript) -> void:
	"""An empty pantry over these storage locations."""
	storage = p_storage
	for column: PackedInt32Array in [_lot_item, _lot_location, _lot_remainder]:
		column.resize(MAX_LOTS)
	for column: PackedInt64Array in [_lot_milli, _lot_age]:
		column.resize(MAX_LOTS)
	_lot_item.fill(FREE)
	_item_milli.resize(Catalog.ITEM_COUNT)
	_ids.resize(MAX_LOTS)


func add_into(item: int, milli: int, location: int, out: IntMath.IntResult) -> bool:
	"""Store `milli` of `item` at `location` as a fresh lot (see the header on a full table). Writes
	the lot row into `out`; refuses a bad item, quantity or location, or one without the room."""
	if not Catalog.is_item(item):
		return out.refuse(REFUSE_NOT_AN_ITEM)
	if milli <= 0:
		return out.refuse(REFUSE_BAD_QUANTITY)
	if location < 0 or location >= storage.count():
		return out.refuse(REFUSE_NO_LOCATION)
	if used_milli_of(location) + milli > storage.capacity_milli_of(location):
		return out.refuse(REFUSE_NO_ROOM)
	var lot: int = _lot_item.find(FREE)
	if lot >= 0:
		_open_lot(lot, item, location)
	elif _oldest_lot_into(item, location, out):
		lot = out.value
	else:
		return out.refuse(REFUSE_NO_ROOM)
	_lot_milli[lot] += milli
	_item_milli[item] += milli
	return out.succeed(lot)


func _open_lot(lot: int, item: int, location: int) -> void:
	"""Start an empty, age-0 lot of `item` at `location` in a free row."""
	_lot_item[lot] = item
	_lot_location[lot] = location
	_lot_milli[lot] = 0
	_lot_age[lot] = 0
	_lot_remainder[lot] = 0


func _oldest_lot_into(item: int, location: int, out: IntMath.IntResult) -> bool:
	"""The oldest live lot of `item` at `location`, into `out`; refuses NO_STOCK when none."""
	var found: bool = false
	for lot: int in MAX_LOTS:
		if _lot_item[lot] == item and _lot_location[lot] == location:
			if not found or _lot_age[lot] > _lot_age[out.value]:
				found = out.succeed(lot)
	if not found:
		return out.refuse(REFUSE_NO_STOCK)
	return true


func location_for_into(milli: int, out: IntMath.IntResult) -> bool:
	"""Where a delivery of `milli` should go: the location that spoils slowest (lowest permille) with
	room for all of it, the lowest index on a tie. Refuses NO_STORAGE_ROOM."""
	var best: int = FREE
	for location: int in storage.count():
		if used_milli_of(location) + milli > storage.capacity_milli_of(location):
			continue
		if best == FREE or storage.permille_of(location) < storage.permille_of(best):
			best = location
	if best == FREE:
		return out.refuse(REFUSE_NO_ROOM)
	return out.succeed(best)


func used_milli_of(location: int) -> int:
	"""How much a location holds now, milli-U."""
	var used: int = 0
	for lot: int in MAX_LOTS:
		if _lot_item[lot] != FREE and _lot_location[lot] == location:
			used += _lot_milli[lot]
	return used


func refresh_locations() -> void:
	"""Re-read the storage providers, keeping every lot with its location by id; a lot whose location
	has gone moves to the covered store (location 0)."""
	for lot: int in MAX_LOTS:
		_ids[lot] = storage.id_of(_lot_location[lot]) if _lot_item[lot] != FREE else null
	storage.refresh()
	for lot: int in MAX_LOTS:
		if _lot_item[lot] == FREE:
			continue
		_lot_location[lot] = _read.value if storage.index_of_id_into(_ids[lot], _read) else 0


# --- spoilage (§5.8) --------------------------------------------------------------------------

func age_hour(season: int) -> int:
	"""Age every lot one game hour in `season`; spoil any that reach their shelf life. Returns how
	many lots spoiled this hour."""
	var temperature: int = StockAge.temperature_factor_of(season, false)
	var spoiled: int = 0
	for lot: int in MAX_LOTS:
		if _lot_item[lot] == FREE:
			continue
		var numerator: int = storage.permille_of(_lot_location[lot]) * temperature + _lot_remainder[lot]
		_lot_age[lot] += numerator / FACTOR_DENOMINATOR
		_lot_remainder[lot] = numerator % FACTOR_DENOMINATOR
		if _lot_age[lot] >= Catalog.shelf_hours_of(_lot_item[lot]) * FACTOR_DENOMINATOR:
			_spoil(lot)
			spoiled += 1
	return spoiled


func _spoil(lot: int) -> void:
	"""A lot at its shelf life becomes spoiled food at equal mass and frees its row."""
	var item: int = _lot_item[lot]
	_item_milli[item] -= _lot_milli[lot]
	spoiled_milli += _lot_milli[lot]
	_spoiled_items.append(item)
	_lot_item[lot] = FREE
	_lot_milli[lot] = 0


func compost_spoiled() -> int:
	"""Send spoiled food to compost at §5.7's 4 : 2; returns the compost made (milli-U). An odd
	milli-U that cannot convert whole stays spoiled."""
	var taken: int = spoiled_milli - spoiled_milli % (COMPOST_FROM_SPOILED_IN / COMPOST_FROM_SPOILED_OUT)
	spoiled_milli -= taken
	return taken * COMPOST_FROM_SPOILED_OUT / COMPOST_FROM_SPOILED_IN


func take_spoiled_items_into(out: PackedInt32Array) -> int:
	"""Move the items that spoiled since last asked into `out` (appended); returns how many."""
	var count: int = _spoiled_items.size()
	out.append_array(_spoiled_items)
	_spoiled_items.clear()
	return count


# --- readouts -------------------------------------------------------------------------------

func milli_of(item: int) -> int:
	"""How much of an item the pantry holds, milli-U."""
	return _item_milli[item]


func units_of(item: int) -> int:
	"""Whole units of an item (what the pantry counts)."""
	return _item_milli[item] / MILLI_PER_U


func total_units() -> int:
	"""Every item's whole units, added up: the HUD's Food figure."""
	var total: int = 0
	for item: int in Catalog.ITEM_COUNT:
		total += units_of(item)
	return total


func hours_left_into(item: int, out: IntMath.IntResult) -> bool:
	"""Effective hours until the item's OLDEST lot spoils; refuses NO_STOCK with none held."""
	var least: int = -1
	for lot: int in MAX_LOTS:
		if _lot_item[lot] == item:
			var left: int = Catalog.shelf_hours_of(item) * FACTOR_DENOMINATOR - _lot_age[lot]
			if least < 0 or left < least:
				least = left
	if least < 0:
		return out.refuse(REFUSE_NO_STOCK)
	return out.succeed(least / FACTOR_DENOMINATOR)


func freshness_permille_into(item: int, out: IntMath.IntResult) -> bool:
	"""How much shelf life the item's oldest lot has left, per 1000; refuses NO_STOCK."""
	if not hours_left_into(item, out):
		return false
	return out.succeed(out.value * FACTOR_DENOMINATOR / Catalog.shelf_hours_of(item))


func milli_at(item: int, location: int) -> int:
	"""How much of an item one location holds, milli-U."""
	var held: int = 0
	for lot: int in MAX_LOTS:
		if _lot_item[lot] == item and _lot_location[lot] == location:
			held += _lot_milli[lot]
	return held


func lot_count() -> int:
	"""How many lots are live."""
	return MAX_LOTS - _lot_item.count(FREE)


func lot_age(lot: int) -> int:
	"""A lot's effective age, milli-hours (tests)."""
	return _lot_age[lot]


func lot_location(lot: int) -> int:
	"""A lot's location index (tests)."""
	return _lot_location[lot]
