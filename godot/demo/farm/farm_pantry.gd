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
##
## RESERVATIONS (decision 0222). A harvest reserves its room before it is cut (`reserve_near_into`), so a
## full store never destroys one (the review's F19): the room a HOLD keeps is not free to anyone else
## (`add_into`, `location_for_into` and `location_near_into` all count it as taken). A delivery stores
## against its own hold (`store_upto`), taking WHAT FITS when the store shrank meanwhile (a cellar's racks
## taken out) and saying how much, so the carrier keeps the rest. A hold follows its store by id across
## `refresh_locations`, like a lot; a hold whose store has gone answers STORAGE_LOCATION_GONE. A hold names its
## item, so the Pantry can show what is INCOMING per ingredient and store (`incoming_milli`, decision 0292).
##
## THE FORECAST (`next_spoil_into`, F27) is in CALENDAR hours: the hour crossings until a lot spoils, each
## aging it at its store's factor and at the season of that crossing -- the very sum `age_hour` will make,
## season changes included. The first lot to spoil is found across stores (`first_to_spoil_into`), not the
## oldest by effective age.
##
## WITHDRAWALS (decision 0381, the kitchen). Food leaves a lot only by spoiling or by `withdraw_into` -- the cook's
## batch taking its ingredients, a hungry resident's raw emergency meal. A lot row is reused once freed, so every
## opening gives the row a new SERIAL (`lot_serial`): a reservation made against (row, serial) can never draw on
## another lot that happens to take the same row later (demo/kitchen/ingredient_takes.gd).
##
## THE LEDGER (decision 0451, the seasonal planner's after-action record). Per item, never reset: every milli-U that
## came IN (a delivery stored: `_lot_into`, the one place a lot grows), went OUT (`withdraw_into`) and SPOILED (`_spoil`).
## Committed outcomes only -- a reservation, a load in hand or a composting moves none of them -- so for every item
## `milli_of == stored_total_milli - withdrawn_total_milli - spoiled_total_milli` (test_demo_planner.gd checks it).

const Catalog := preload("res://demo/farm/farm_catalog.gd")
const StorageScript := preload("res://demo/farm/farm_storage.gd")
const StockAge := preload("res://scripts/core/stock_age.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")

const MAX_LOTS: int = 128
## Reservations held at once: the farm's job board is 24 rows, each with at most one.
const MAX_HOLDS: int = 32
const FREE: int = -1
const MILLI_PER_U: int = 1000
const FACTOR_DENOMINATOR: int = 1000
## Metres to the tunnel network's integer u (1/1024 m), for comparing haul distances exactly.
const U_PER_M: float = 1024.0
## §5.7: "compost | spoiled_food 4 ... | compost 2".
const COMPOST_FROM_SPOILED_IN: int = 4
const COMPOST_FROM_SPOILED_OUT: int = 2
## Game hours in a season (sim_clock.gd: 12 days of 24 hours).
const HOURS_PER_SEASON: int = SimClock.DAYS_PER_SEASON * SimClock.HOURS_PER_DAY

const REFUSE_NOT_AN_ITEM: String = "NOT_AN_ITEM"
const REFUSE_BAD_QUANTITY: String = "INVALID_QUANTITY"
const REFUSE_NO_LOCATION: String = "NO_SUCH_LOCATION"
const REFUSE_NO_ROOM: String = "NO_STORAGE_ROOM"
const REFUSE_NO_STOCK: String = "NO_STOCK"
const REFUSE_NO_HOLD: String = "NO_RESERVATION_ROW"
const REFUSE_GONE: String = "STORAGE_LOCATION_GONE"
const REFUSE_STALE_LOT: String = "LOT_NOT_THE_SAME"
## A hold's location once its store has gone (never a location index).
const GONE: int = -2

var storage: StorageScript = null
var spoiled_milli: int = 0
## Every milli-U a DELIVERY has ever shelved (`store_upto_into`: a harvest carried to its store), and the item of the
## latest: the first-village guide's "a harvest came into store" (demo/guide/, decision 0481). `add_into` (a test's or a
## fixture's stocking) never counts.
var delivered_milli: int = 0
var last_delivered_item: int = FREE

var _lot_item: PackedInt32Array = PackedInt32Array()
var _lot_location: PackedInt32Array = PackedInt32Array()
var _lot_milli: PackedInt64Array = PackedInt64Array()
var _lot_age: PackedInt64Array = PackedInt64Array()
var _lot_remainder: PackedInt32Array = PackedInt32Array()
var _item_milli: PackedInt64Array = PackedInt64Array()
var _spoiled_items: PackedInt32Array = PackedInt32Array()
## THE LEDGER (see the header): per item, cumulative milli-U stored, withdrawn and spoiled.
var _in_milli: PackedInt64Array = PackedInt64Array()
var _out_milli: PackedInt64Array = PackedInt64Array()
var _spoiled_by_item: PackedInt64Array = PackedInt64Array()
var _ids: Array = []
var _read: IntMath.IntResult = IntMath.IntResult.new()
var _hold_live: PackedByteArray = PackedByteArray()
var _hold_location: PackedInt32Array = PackedInt32Array()
var _hold_milli: PackedInt64Array = PackedInt64Array()
## What each hold's harvest is (the Pantry's "incoming" per item; decision 0292). FREE on a free row.
var _hold_item: PackedInt32Array = PackedInt32Array()
var _hold_ids: Array = []
## `_lot_row_for`'s own scratch (its callers' `out` may be any other).
var _lot_probe: IntMath.IntResult = IntMath.IntResult.new()
## Each lot row's serial, new every time the row opens (see WITHDRAWALS); 0 on a row never opened.
var _lot_serial: PackedInt32Array = PackedInt32Array()
var _next_serial: int = 1


func _init(p_storage: StorageScript) -> void:
	"""An empty pantry over these storage locations."""
	storage = p_storage
	for column: PackedInt32Array in [_lot_item, _lot_location, _lot_remainder, _lot_serial]:
		column.resize(MAX_LOTS)
	for column: PackedInt64Array in [_lot_milli, _lot_age]:
		column.resize(MAX_LOTS)
	_lot_item.fill(FREE)
	_item_milli.resize(Catalog.PANTRY_ITEM_COUNT)
	for column: PackedInt64Array in [_in_milli, _out_milli, _spoiled_by_item]:
		column.resize(Catalog.PANTRY_ITEM_COUNT)
	_ids.resize(MAX_LOTS)
	_hold_live.resize(MAX_HOLDS)
	_hold_location.resize(MAX_HOLDS)
	_hold_milli.resize(MAX_HOLDS)
	_hold_item.resize(MAX_HOLDS)
	_hold_item.fill(FREE)
	_hold_ids.resize(MAX_HOLDS)


func add_into(item: int, milli: int, location: int, out: IntMath.IntResult) -> bool:
	"""Store `milli` of `item` at `location` as a fresh lot (see the header on a full table). Writes
	the lot row into `out`; refuses a bad item, quantity or location, or one without the room -- room a
	reservation holds is not free."""
	if not Catalog.is_pantry_item(item):
		return out.refuse(REFUSE_NOT_AN_ITEM)
	if milli <= 0:
		return out.refuse(REFUSE_BAD_QUANTITY)
	if location < 0 or location >= storage.count():
		return out.refuse(REFUSE_NO_LOCATION)
	if room_milli_of(location) < milli:
		return out.refuse(REFUSE_NO_ROOM)
	return _lot_into(item, milli, location, out)


func _lot_into(item: int, milli: int, location: int, out: IntMath.IntResult) -> bool:
	"""Put `milli` of `item` into a new lot at `location` (room already checked), or merge it into the
	oldest such lot when the table is full. The lot into `out`; refuses NO_STORAGE_ROOM."""
	var lot: int = _lot_item.find(FREE)
	if lot >= 0:
		_open_lot(lot, item, location)
	elif _oldest_lot_into(item, location, out):
		lot = out.value
	else:
		return out.refuse(REFUSE_NO_ROOM)
	_lot_milli[lot] += milli
	_item_milli[item] += milli
	_in_milli[item] += milli
	return out.succeed(lot)


func _open_lot(lot: int, item: int, location: int) -> void:
	"""Start an empty, age-0 lot of `item` at `location` in a free row."""
	_lot_item[lot] = item
	_lot_location[lot] = location
	_lot_milli[lot] = 0
	_lot_age[lot] = 0
	_lot_remainder[lot] = 0
	_lot_serial[lot] = _next_serial
	_next_serial += 1


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
	return _best_location_into(milli, Catalog.NO_ITEM, false, Vector2i.ZERO, out)


func location_for_item_into(item: int, milli: int, out: IntMath.IntResult) -> bool:
	"""`location_for_into` for a delivery of `item`: a location only where a lot of it can also be kept
	(a free lot row, or one of its own there to merge into). Refuses NO_STORAGE_ROOM."""
	return _best_location_into(milli, item, false, Vector2i.ZERO, out)


func location_near_into(milli: int, from: Vector2, out: IntMath.IntResult) -> bool:
	"""Where a harvest carried from `from` (x, z metres; its bed) should go: the slowest-spoiling
	location with room for all of it, and among equals the one nearest `from` -- so a root cellar dug
	near the beds shortens the haul. Distances are compared in integer u, converted once. Refuses
	NO_STORAGE_ROOM."""
	return _near_into(milli, Catalog.NO_ITEM, from, out)


func _near_into(milli: int, item: int, from: Vector2, out: IntMath.IntResult) -> bool:
	"""`location_near_into`, for `item` (NO_ITEM: any) -- see `_best_location_into`."""
	return _best_location_into(milli, item, true, Vector2i(roundi(from.x * U_PER_M), roundi(from.y * U_PER_M)), out)


func _best_location_into(milli: int, item: int, by_distance: bool, from_u: Vector2i, out: IntMath.IntResult) -> bool:
	"""The lowest-permille location with room (and, for an `item`, a lot to keep it in); ties to the
	nearest `from_u` (by_distance) or the lowest index. Refuses NO_STORAGE_ROOM."""
	var best: int = FREE
	for location: int in storage.count():
		if room_milli_of(location) < milli or not _lot_row_for(item, location):
			continue
		if best == FREE or storage.permille_of(location) < storage.permille_of(best):
			best = location
		elif by_distance and storage.permille_of(location) == storage.permille_of(best) \
				and _distance2_u(location, from_u) < _distance2_u(best, from_u):
			best = location
	if best == FREE:
		return out.refuse(REFUSE_NO_ROOM)
	return out.succeed(best)


func _lot_row_for(item: int, location: int) -> bool:
	"""Whether a delivery of `item` could be kept at `location` as a lot: a free row, or a lot of it there
	to merge into (`_lot_into`). Any location for NO_ITEM (a room-only question)."""
	if not Catalog.is_pantry_item(item) or _lot_item.find(FREE) >= 0:
		return true
	return _oldest_lot_into(item, location, _lot_probe)


func _distance2_u(location: int, from_u: Vector2i) -> int:
	"""Squared distance, in u, from `from_u` to where a location is delivered to."""
	var at: Vector2 = storage.position_of(location)
	var dx: int = roundi(at.x * U_PER_M) - from_u.x
	var dz: int = roundi(at.y * U_PER_M) - from_u.y
	return dx * dx + dz * dz


func used_milli_of(location: int) -> int:
	"""How much a location holds now, milli-U."""
	var used: int = 0
	for lot: int in MAX_LOTS:
		if _lot_item[lot] != FREE and _lot_location[lot] == location:
			used += _lot_milli[lot]
	return used


func refresh_locations() -> void:
	"""Re-read the storage providers, keeping every lot and hold with its location by id; a lot whose
	location has gone moves to the covered store (location 0), a hold whose location has gone is GONE."""
	for lot: int in MAX_LOTS:
		_ids[lot] = storage.id_of(_lot_location[lot]) if _lot_item[lot] != FREE else null
	for hold: int in MAX_HOLDS:
		_hold_ids[hold] = storage.id_of(_hold_location[hold]) if _holds_place(hold) else null
	storage.refresh()
	for lot: int in MAX_LOTS:
		if _lot_item[lot] == FREE:
			continue
		_lot_location[lot] = _read.value if storage.index_of_id_into(_ids[lot], _read) else 0
	for hold: int in MAX_HOLDS:
		if _holds_place(hold):
			_hold_location[hold] = _read.value if storage.index_of_id_into(_hold_ids[hold], _read) else GONE


func room_milli_of(location: int) -> int:
	"""What a location can still take, milli-U: its capacity less what it holds and what is reserved
	there (never below 0 -- a store that shrank under its stock has no room)."""
	return maxi(0, storage.capacity_milli_of(location) - used_milli_of(location) - reserved_milli_of(location))


func total_milli() -> int:
	"""Every item's stock added up, milli-U: the HUD's Food figure and the Pantry's total (F28: summed
	before it is formatted)."""
	var total: int = 0
	for item: int in Catalog.PANTRY_ITEM_COUNT:
		total += _item_milli[item]
	return total


# --- reservations (see the header) -----------------------------------------------------------

func reserve_near_into(item: int, milli: int, from: Vector2, out: IntMath.IntResult) -> bool:
	"""Reserve room for `milli` of `item` at the store a delivery from `from` should go to
	(`location_near_into`'s choice, where a lot of it can be kept). The hold's row into `out`; refuses a
	bad item or quantity, NO_STORAGE_ROOM or a full hold table."""
	if not Catalog.is_pantry_item(item):
		return out.refuse(REFUSE_NOT_AN_ITEM)
	if milli <= 0:
		return out.refuse(REFUSE_BAD_QUANTITY)
	var hold: int = _hold_live.find(0)
	if hold < 0:
		return out.refuse(REFUSE_NO_HOLD)
	if not _near_into(milli, item, from, out):
		return false
	_hold_live[hold] = 1
	_hold_location[hold] = out.value
	_hold_milli[hold] = milli
	_hold_item[hold] = item
	return out.succeed(hold)


func hold_location_into(hold: int, out: IntMath.IntResult) -> bool:
	"""Where hold `hold` keeps its room, into `out`; refuses NO_RESERVATION_ROW for a free row and
	STORAGE_LOCATION_GONE when its store has gone."""
	if not is_hold(hold):
		return out.refuse(REFUSE_NO_HOLD)
	if _hold_location[hold] == GONE:
		return out.refuse(REFUSE_GONE)
	return out.succeed(_hold_location[hold])


func is_hold(hold: int) -> bool:
	"""Whether `hold` is a live reservation."""
	return hold >= 0 and hold < MAX_HOLDS and _hold_live[hold] == 1


func hold_item(hold: int) -> int:
	"""The item hold `hold` keeps room for (FREE for a free row)."""
	return _hold_item[hold] if is_hold(hold) else FREE


func hold_milli(hold: int) -> int:
	"""How much hold `hold` keeps room for, milli-U (0 for a free row)."""
	return _hold_milli[hold] if is_hold(hold) else 0


func resize_hold(hold: int, milli: int) -> bool:
	"""Make hold `hold` keep room for `milli` instead: shrinking always takes, growing only into free
	room at its store. False (the hold unchanged) when it cannot."""
	if not is_hold(hold) or _hold_location[hold] == GONE or milli <= 0:
		return false
	if milli > _hold_milli[hold] and room_milli_of(_hold_location[hold]) < milli - _hold_milli[hold]:
		return false
	_hold_milli[hold] = milli
	return true


func release(hold: int) -> void:
	"""Give up hold `hold`'s room (a free row: nothing)."""
	if is_hold(hold):
		_hold_live[hold] = 0
		_hold_milli[hold] = 0
		_hold_item[hold] = FREE


func reserved_milli_of(location: int) -> int:
	"""How much room reservations keep at a location, milli-U."""
	var held: int = 0
	for hold: int in MAX_HOLDS:
		if _holds_place(hold) and _hold_location[hold] == location:
			held += _hold_milli[hold]
	return held


func incoming_milli(item: int, location: int) -> int:
	"""How much of `item` live holds keep room for at `location`, milli-U: a harvest being cut or carried
	there (the Pantry's "incoming"; a hold whose store has gone counts nowhere)."""
	var held: int = 0
	for hold: int in MAX_HOLDS:
		if _holds_place(hold) and _hold_item[hold] == item and _hold_location[hold] == location:
			held += _hold_milli[hold]
	return held


func store_upto_into(item: int, milli: int, location: int, hold: int, out: IntMath.IntResult) -> bool:
	"""A delivery of `milli` of `item` at `location`, against hold `hold` when it is there (else none):
	stores WHAT FITS -- the free room plus the hold's own -- as a lot, draws the hold down by it (to
	nothing when not all of it fitted: that store has no more room to keep). How much was stored into
	`out` (0 when nothing fitted, or no lot row was to be had); refuses a bad item, quantity or location."""
	if not Catalog.is_pantry_item(item):
		return out.refuse(REFUSE_NOT_AN_ITEM)
	if milli <= 0:
		return out.refuse(REFUSE_BAD_QUANTITY)
	if location < 0 or location >= storage.count():
		return out.refuse(REFUSE_NO_LOCATION)
	var own: int = _hold_milli[hold] if _holds_place(hold) and _hold_location[hold] == location else 0
	var free: int = storage.capacity_milli_of(location) - used_milli_of(location) - reserved_milli_of(location) + own
	var fits: int = mini(milli, free)
	if fits <= 0 or not _lot_into(item, fits, location, _read):
		return out.succeed(0)
	if own > 0:
		_hold_milli[hold] = maxi(0, own - fits) if fits == milli else 0
	delivered_milli += fits
	last_delivered_item = item
	return out.succeed(fits)


func _holds_place(hold: int) -> bool:
	"""Whether `hold` is a live reservation with a store still standing (FREE and out-of-range rows are
	not)."""
	return is_hold(hold) and _hold_location[hold] != GONE


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
	_spoiled_by_item[item] += _lot_milli[lot]
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


func stored_total_milli(item: int) -> int:
	"""THE LEDGER: every milli-U of `item` ever stored here (deliveries), never reset."""
	return _in_milli[item]


func withdrawn_total_milli(item: int) -> int:
	"""THE LEDGER: every milli-U of `item` ever withdrawn (the kitchen's batches and raw meals), never reset."""
	return _out_milli[item]


func spoiled_total_milli(item: int) -> int:
	"""THE LEDGER: every milli-U of `item` that ever spoiled in store, never reset (composting does not touch it)."""
	return _spoiled_by_item[item]


func units_of(item: int) -> int:
	"""Whole units of an item (what the pantry counts)."""
	return _item_milli[item] / MILLI_PER_U


func hours_left_into(item: int, out: IntMath.IntResult) -> bool:
	"""BASE shelf-life hours left on the item's OLDEST lot (effective age at the base rate, not a
	calendar countdown -- `next_spoil_into` is that); refuses NO_STOCK with none held."""
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


func first_to_spoil_into(item: int, hour_index: int, out: IntMath.IntResult) -> bool:
	"""The item's lot that spoils FIRST in calendar hours from the demo calendar's `hour_index` (its
	store's rate and each season's), into `out`; the lowest row on a tie. Refuses NO_STOCK."""
	var best: int = FREE
	var best_hours: int = 0
	for lot: int in MAX_LOTS:
		if _lot_item[lot] != item:
			continue
		var hours: int = lot_spoil_hours(lot, hour_index)
		if best == FREE or hours < best_hours:
			best = lot
			best_hours = hours
	if best == FREE:
		return out.refuse(REFUSE_NO_STOCK)
	return out.succeed(best)


func first_to_spoil_at_into(item: int, location: int, hour_index: int, out: IntMath.IntResult) -> bool:
	"""The lot of `item` at `location` that spoils first from `hour_index` (as `first_to_spoil_into`, kept to
	one store), into `out`; the lowest row on a tie. Refuses NO_STOCK."""
	var best: int = FREE
	var best_hours: int = 0
	for lot: int in MAX_LOTS:
		if _lot_item[lot] != item or _lot_location[lot] != location:
			continue
		var hours: int = lot_spoil_hours(lot, hour_index)
		if best == FREE or hours < best_hours:
			best = lot
			best_hours = hours
	if best == FREE:
		return out.refuse(REFUSE_NO_STOCK)
	return out.succeed(best)


func next_spoil_into(item: int, hour_index: int, out: IntMath.IntResult) -> bool:
	"""Calendar hours until the item's first lot spoils (see `first_to_spoil_into`); refuses NO_STOCK."""
	if not first_to_spoil_into(item, hour_index, out):
		return false
	return out.succeed(lot_spoil_hours(out.value, hour_index))


func lot_spoil_hours(lot: int, hour_index: int) -> int:
	"""How many hour crossings after `hour_index` lot `lot` spoils at: `age_hour`'s own integer sum,
	season by season. The crossing into hour h ages at the season of hour h (`season_of_hour`)."""
	var permille: int = storage.permille_of(_lot_location[lot])
	var needed: int = Catalog.shelf_hours_of(_lot_item[lot]) * FACTOR_DENOMINATOR - _lot_age[lot]
	var carried: int = _lot_remainder[lot]
	var hours: int = 0
	if needed <= 0:
		return 1
	while needed > 0:
		var hour: int = hour_index + hours + 1
		var rate: int = maxi(1, permille * StockAge.temperature_factor_of(season_of_hour(hour), false))
		var span: int = HOURS_PER_SEASON - posmod(hour, HOURS_PER_SEASON)
		var to_spoil: int = (needed * FACTOR_DENOMINATOR - carried + rate - 1) / rate
		if to_spoil <= span:
			return hours + to_spoil
		var aged: int = rate * span + carried
		needed -= aged / FACTOR_DENOMINATOR
		carried = aged % FACTOR_DENOMINATOR
		hours += span
	return hours


static func season_of_hour(hour_index: int) -> int:
	"""The season (0 spring .. 3 winter) of the calendar hour `hour_index` counts from the midnight
	before spring day 1 (demo_calendar.gd `hour_index`)."""
	var day: int = hour_index / SimClock.HOURS_PER_DAY
	return (day % SimClock.DAYS_PER_YEAR) / SimClock.DAYS_PER_SEASON


func lot_milli(lot: int) -> int:
	"""How much a lot holds, milli-U."""
	return _lot_milli[lot]


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


func lot_item(lot: int) -> int:
	"""A lot's item (FREE for a free row)."""
	return _lot_item[lot]


func lot_location(lot: int) -> int:
	"""A lot's location index (tests)."""
	return _lot_location[lot]


func lot_serial(lot: int) -> int:
	"""The serial lot row `lot` was opened with (see WITHDRAWALS); 0 for a free row."""
	return _lot_serial[lot] if _lot_item[lot] != FREE else 0


func withdraw_into(lot: int, serial: int, milli: int, out: IntMath.IntResult) -> bool:
	"""Take `milli` out of lot `lot`, which must still be the lot opened with `serial` (see WITHDRAWALS): its item's
	count falls by exactly that much and an emptied row is freed. How much was taken into `out`; refuses a stale or
	free row (LOT_NOT_THE_SAME), a bad quantity or more than the lot holds (NO_STOCK), changing nothing."""
	if lot < 0 or lot >= MAX_LOTS or _lot_item[lot] == FREE or _lot_serial[lot] != serial:
		return out.refuse(REFUSE_STALE_LOT)
	if milli <= 0:
		return out.refuse(REFUSE_BAD_QUANTITY)
	if milli > _lot_milli[lot]:
		return out.refuse(REFUSE_NO_STOCK)
	_lot_milli[lot] -= milli
	_item_milli[_lot_item[lot]] -= milli
	_out_milli[_lot_item[lot]] += milli
	if _lot_milli[lot] == 0:
		_lot_item[lot] = FREE
	return out.succeed(milli)
