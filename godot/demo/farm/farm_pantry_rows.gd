extends RefCounted
## The Pantry's Stocks table: what is in store, where, what is on its way and what spoils next. Decision
## 0292 (the review's F46). Presentation only; it reads the pantry (farm_pantry.gd) and writes nothing.
##
## ROWS. One row per (item, store) that holds some of the item or has a harvest of it on its way -- a
## live reservation (decision 0222's holds), "incoming". A row keeps its store by ID, as lots and holds
## do, and finds its index again on every update, so a store taken away while the Pantry is open (a
## cellar's racks out: `refresh_locations`) leaves its rows reading "store gone" and empty, never another
## store's figures. Each update is ONE pass over the lots and one over the holds (`update`), into
## packed figures per row: in store, incoming, the first lot there to spoil and its calendar hours
## (`lot_spoil_hours`, the very sum the hourly ageing makes). Zero stock with a harvest incoming reads
## "0 U" in store and the incoming amount, never "none".
##
## ORDER. Rows are put in order only when the table is BUILT (`rebuild`: the Pantry opening, or its Stocks
## tab chosen): food that spoils within SOON_HOURS first, soonest first (a tie keeps the catalog's order);
## then the rest in the catalog's item order, store by store. While the Pantry stays open the order is
## KEPT (`update`): figures change in place, a row that appears goes at the end, and a row whose stock
## has gone stays where it is reading "0 U", so nothing moves under the pointer (the review's P1: numeric
## changes do not reorder the focused row).
##
## STORES are rows too (`store_cells`): stored, reserved for harvests on their way, free, capacity and
## how fast the store ages food. Under them, WHY (decision 0611): each store's own words for how it keeps food and how
## many times as long food keeps there as in the covered store (`why_text`); and a row whose store has food in a
## carrier's hands, on its way to a cooler store, says so (`moving_text`).
##
## EMPTY. With no row at all the Pantry suggests a real source from the beds (`suggest`): a ripe bed to
## harvest, else the bed that ripens soonest, else an empty bed to plant, else a dead crop to clear.

const PantryScript := preload("res://demo/farm/farm_pantry.gd")
const SimScript := preload("res://demo/farm/farm_sim.gd")
const Catalog := preload("res://demo/farm/farm_catalog.gd")
const StorageScript := preload("res://demo/farm/farm_storage.gd")
const Text := preload("res://demo/farm/farm_text.gd")
const IntMath := preload("res://scripts/core/int_math.gd")

## Food that spoils within this many game hours is "soon" and goes first (demo value: two game days).
const SOON_HOURS: int = 48
const NO_BED: int = -1
## A row's store index once that store has gone, and a row's first lot with nothing in store.
const GONE: int = -1
const NO_LOT: int = -1
## A row with nothing in store and nothing incoming (its stock gone while the Pantry was open).
const NONE_TEXT: String = "—"
const GONE_TEXT: String = "(store gone)"
## WHY (decision 0611; see STORES).
const WHY_HEADING: String = "Why food keeps longer in some stores:"
const WHY_KEEPS: String = ": food keeps %s as long as in the %s"
const MOVING: String = "%s being moved to a cooler store"

## The rows in display order: item, store index (GONE once its store has gone) and the store's id.
var item: PackedInt32Array = PackedInt32Array()
var location: PackedInt32Array = PackedInt32Array()
## Each row's figures as of the last `update`: in store and incoming (milli-U), its first lot to spoil
## (NO_LOT: none) and that lot's calendar hours.
var milli: PackedInt64Array = PackedInt64Array()
var incoming: PackedInt64Array = PackedInt64Array()
var first_lot: PackedInt32Array = PackedInt32Array()
var hours: PackedInt32Array = PackedInt32Array()
## The empty pantry's suggestion and the bed it names (`suggest`).
var suggestion: String = ""
var suggested_bed: int = NO_BED

var _ids: Array = []
var _key: PackedInt32Array = PackedInt32Array()
var _read: IntMath.IntResult = IntMath.IntResult.new()
var _ripe_hours: int = 0


func count() -> int:
	"""How many rows the table has."""
	return item.size()


func rebuild(pantry: PantryScript, hour_index: int) -> int:
	"""Every (item, store) with stock or a harvest incoming, soonest-to-spoil first (see ORDER). Returns
	the row count."""
	_clear()
	update(pantry, hour_index)
	_key.resize(item.size())
	for row: int in item.size():
		_key[row] = _sort_key(row)
	for row: int in range(1, item.size()):
		_sink(row)
	update(pantry, hour_index)
	return item.size()


func update(pantry: PantryScript, hour_index: int) -> int:
	"""Find each row's store again by id, append every (item, store) now present that is not listed (see
	ORDER), and refigure every row in one pass over the lots and one over the holds. Returns how many rows
	were added."""
	var before: int = item.size()
	for row: int in item.size():
		location[row] = _read.value if pantry.storage.index_of_id_into(_ids[row], _read) else GONE
		milli[row] = 0
		incoming[row] = 0
		first_lot[row] = NO_LOT
	for lot: int in PantryScript.MAX_LOTS:
		if pantry.lot_item(lot) != PantryScript.FREE:
			_count_lot(pantry, lot, hour_index)
	for hold: int in PantryScript.MAX_HOLDS:
		if pantry.is_hold(hold) and pantry.hold_location_into(hold, _read):
			incoming[_row_for(pantry, pantry.hold_item(hold), _read.value)] += pantry.hold_milli(hold)
	return item.size() - before


func _count_lot(pantry: PantryScript, lot: int, hour_index: int) -> void:
	"""Add one lot to its row: its milli-U, and it as the row's first to spoil when it is the soonest (the
	lowest lot row on a tie, as `first_to_spoil_into`)."""
	var row: int = _row_for(pantry, pantry.lot_item(lot), pantry.lot_location(lot))
	milli[row] += pantry.lot_milli(lot)
	var left: int = pantry.lot_spoil_hours(lot, hour_index)
	if first_lot[row] == NO_LOT or left < hours[row]:
		first_lot[row] = lot
		hours[row] = left


func _row_for(pantry: PantryScript, it: int, at: int) -> int:
	"""The row listing `it` at store `at`, appended (empty) when there is none."""
	var row: int = row_of(it, at)
	if row >= 0:
		return row
	item.append(it)
	location.append(at)
	_ids.append(pantry.storage.id_of(at))
	milli.append(0)
	incoming.append(0)
	first_lot.append(NO_LOT)
	hours.append(0)
	return item.size() - 1


func row_of(it: int, at: int) -> int:
	"""The row listing `it` at store `at`, or -1 when none does."""
	for row: int in item.size():
		if item[row] == it and location[row] == at:
			return row
	return -1


func _clear() -> void:
	"""No rows."""
	item.clear()
	location.clear()
	milli.clear()
	incoming.clear()
	first_lot.clear()
	hours.clear()
	_ids.clear()


func _sort_key(row: int) -> int:
	"""Soon rows by their hours, a tie in catalog order; every other row after them in catalog order,
	store by store."""
	var catalog: int = item[row] * StorageScript.MAX_LOCATIONS + maxi(location[row], 0)
	var span: int = Catalog.PANTRY_ITEM_COUNT * StorageScript.MAX_LOCATIONS
	return (hours[row] if is_soon(row) else SOON_HOURS + 1) * span + catalog


func _sink(row: int) -> void:
	"""One insertion-sort step: move `row` up past every row with a larger key (stable). Only the keys,
	the items, the stores and their ids move; `rebuild` refigures after."""
	var k: int = row
	while k > 0 and _key[k - 1] > _key[k]:
		var held: Vector3i = Vector3i(_key[k - 1], item[k - 1], location[k - 1])
		var id: Variant = _ids[k - 1]
		_key[k - 1] = _key[k]
		item[k - 1] = item[k]
		location[k - 1] = location[k]
		_ids[k - 1] = _ids[k]
		_key[k] = held.x
		item[k] = held.y
		location[k] = held.z
		_ids[k] = id
		k -= 1


func is_soon(row: int) -> bool:
	"""Whether the row's first lot spoils within SOON_HOURS."""
	return first_lot[row] != NO_LOT and hours[row] <= SOON_HOURS


func available_text(row: int) -> String:
	"""What the row's store holds of its item ("0 U" once it has gone)."""
	return Text.units_text(milli[row])


func incoming_text(row: int) -> String:
	"""What is on its way to the row's store, or a dash."""
	return Text.units_text(incoming[row]) if incoming[row] > 0 else NONE_TEXT


func store_text(pantry: PantryScript, row: int) -> String:
	"""The row's store by name ("(store gone)" once it has gone)."""
	return pantry.storage.label_of(location[row]) if location[row] != GONE else GONE_TEXT


func spoil_text(pantry: PantryScript, row: int) -> String:
	"""'all in 6d 16h' (the whole of it is one lot), '2.0 U in 3d 4h' (the first of several), with
	'Soon: ' before it within SOON_HOURS; a dash with nothing in store."""
	if first_lot[row] == NO_LOT:
		return NONE_TEXT
	var lot_milli: int = pantry.lot_milli(first_lot[row])
	var amount: String = "all" if lot_milli == milli[row] else Text.units_text(lot_milli)
	return "%s%s in %s" % ["Soon: " if is_soon(row) else "", amount, until_text(hours[row])]


static func until_text(span_hours: int) -> String:
	"""Game hours as days and hours: '20h', '2d', '7d 22h'."""
	if span_hours < 24:
		return "%dh" % span_hours
	if span_hours % 24 == 0:
		@warning_ignore("integer_division") return "%dd" % (span_hours / 24)
	@warning_ignore("integer_division") return "%dd %dh" % [span_hours / 24, span_hours % 24]


static func store_cells(pantry: PantryScript, at: int) -> PackedStringArray:
	"""One store's row: name, stored, reserved for harvests on their way, free, capacity and its ageing
	rate ('×0.35')."""
	var storage := pantry.storage
	var permille: int = storage.permille_of(at)
	@warning_ignore("integer_division") return PackedStringArray([storage.label_of(at), Text.units_text(pantry.used_milli_of(at)),
		Text.units_text(pantry.reserved_milli_of(at)), Text.units_text(pantry.room_milli_of(at)),
		Text.units_text(storage.capacity_milli_of(at)), "×%d.%02d" % [permille / 1000, (permille % 1000) / 10]])


static func why_text(pantry: PantryScript) -> String:
	"""Why food keeps longer in some stores (see STORES): a heading, then a line a store -- 'Root cellar 1 — cool: deep,
	racked and away from any hearth: food keeps 2.8× as long as in the covered store'."""
	var storage := pantry.storage
	var lines := PackedStringArray([WHY_HEADING])
	for at: int in storage.count():
		var line: String = "%s — %s" % [storage.label_of(at), storage.why_of(at)]
		if storage.permille_of(at) != StorageScript.STORE_PERMILLE:
			line += WHY_KEEPS % [Text.keeps_text(StorageScript.STORE_PERMILLE, storage.permille_of(at)),
				StorageScript.STORE_LABEL.to_lower()]
		lines.append(line)
	return "\n".join(lines)


func moving_text(pantry: PantryScript, row: int) -> String:
	"""'5.0 U being moved to a cooler store' when some of the row's food is in a carrier's hands (see STORES), else ''."""
	if location[row] == GONE:
		return ""
	var held: int = pantry.carried_milli_at(item[row], location[row])
	return MOVING % Text.units_text(held) if held > 0 else ""


func suggest(sim: SimScript) -> bool:
	"""The empty pantry's suggestion from the beds (see EMPTY) into `suggestion`, and the bed it names into
	`suggested_bed`. False (both cleared) only with no beds at all."""
	suggestion = ""
	suggested_bed = NO_BED
	if _first_bed_into(sim, SimScript.STAGE_RIPE, _read):
		return _say(_read.value, "Bed %d's %s is ripe: harvest it to fill the pantry." % [_read.value + 1, _crop(sim, _read.value)])
	if _soonest_ripe_into(sim, _read):
		return _say(_read.value, "Nothing is ripe yet: bed %d's %s ripens in about %s. Harvest it then." % [
			_read.value + 1, _crop(sim, _read.value), until_text(_ripe_hours)])
	if _first_bed_into(sim, SimScript.STAGE_EMPTY, _read):
		return _say(_read.value, "Nothing is growing: plant bed %d (open it, then Plant…)." % (_read.value + 1))
	if _first_bed_into(sim, SimScript.STAGE_WITHERED, _read) or _first_bed_into(sim, SimScript.STAGE_BLIGHTED, _read):
		return _say(_read.value, "Bed %d's crop is lost: clear it and plant again." % (_read.value + 1))
	if Catalog.BED_COUNT == 0:
		return false
	return _say(0, "Every bed is sown but not growing now: open bed 1 to see what it needs.")


func _say(bed: int, words: String) -> bool:
	"""Keep a suggestion and its bed; true."""
	suggested_bed = bed
	suggestion = words
	return true


static func _crop(sim: SimScript, bed: int) -> String:
	"""A bed's crop, lower case."""
	return Catalog.ITEM_LABELS[sim.item_of(bed)].to_lower()


static func _first_bed_into(sim: SimScript, stage: int, out: IntMath.IntResult) -> bool:
	"""The first bed at `stage`, into `out`."""
	for bed: int in Catalog.BED_COUNT:
		if sim.stage_of(bed) == stage:
			return out.succeed(bed)
	return out.refuse("NO_BED")


func _soonest_ripe_into(sim: SimScript, out: IntMath.IntResult) -> bool:
	"""The growing bed that ripens soonest at this hour's rate, into `out` (its hours into `_ripe_hours`);
	refuses when none is growing (or every one has stalled)."""
	var best: int = NO_BED
	for bed: int in Catalog.BED_COUNT:
		if not sim.hours_to_ripe_into(bed, out):
			continue
		if best == NO_BED or out.value < _ripe_hours:
			best = bed
			_ripe_hours = out.value
	if best == NO_BED:
		return out.refuse("NO_BED")
	return out.succeed(best)
