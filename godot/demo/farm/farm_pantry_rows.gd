extends RefCounted
## The Pantry's Stocks table: what is in store, where, what is on its way and what spoils next. Decision
## 0292 (the review's F46). Presentation only; it reads the pantry (farm_pantry.gd) and writes nothing.
##
## ROWS. One row per (item, store) that holds some of the item or has a harvest of it on its way -- a
## live reservation (decision 0222's holds), "incoming". Each row's figures: in store (`milli_at`),
## incoming (`incoming_milli`), the store, and the first lot there to spoil with its calendar hours
## (`first_to_spoil_at_into`, the very sum the hourly ageing makes). Zero stock with a harvest incoming
## reads "0 U" in store and the incoming amount, never "none".
##
## ORDER. Rows are put in order only when the table is BUILT (`rebuild`: the Pantry opening, or its Stocks
## tab chosen): food that spoils within SOON_HOURS first, soonest first; then the rest in the catalog's
## item order, store by store. While the Pantry stays open the order is KEPT (`extend`): a refresh
## rewrites the figures in place, a row that appears goes at the end, and a row whose stock has gone stays
## where it is reading "0 U", so nothing moves under the pointer (the review's P1: numeric changes do not
## reorder the focused row).
##
## STORES are rows too (`store_cells`): stored, reserved for harvests on their way, free, capacity and
## how fast the store ages food.
##
## EMPTY. With no row at all the Pantry suggests a real source from the beds (`suggest`): a ripe
## bed to harvest, else the bed that ripens soonest, else an empty bed to plant, else a dead crop to clear.

const PantryScript := preload("res://demo/farm/farm_pantry.gd")
const SimScript := preload("res://demo/farm/farm_sim.gd")
const Catalog := preload("res://demo/farm/farm_catalog.gd")
const Text := preload("res://demo/farm/farm_text.gd")
const IntMath := preload("res://scripts/core/int_math.gd")

## Food that spoils within this many game hours is "soon" and goes first (demo value: two game days).
const SOON_HOURS: int = 48
const NO_BED: int = -1
## A row with nothing in store and nothing incoming (its stock gone while the Pantry was open).
const NONE_TEXT: String = "—"

## The rows in display order: item and store index.
var item: PackedInt32Array = PackedInt32Array()
var location: PackedInt32Array = PackedInt32Array()

## The empty pantry's suggestion and the bed it names (`suggest`).
var suggestion: String = ""
var suggested_bed: int = NO_BED

var _key: PackedInt32Array = PackedInt32Array()
var _ripe_hours: int = 0
var _read: IntMath.IntResult = IntMath.IntResult.new()


func count() -> int:
	"""How many rows the table has."""
	return item.size()


func rebuild(pantry: PantryScript, hour_index: int) -> int:
	"""Every (item, store) with stock or a harvest incoming, soonest-to-spoil first (see ORDER). Returns
	the row count."""
	item.clear()
	location.clear()
	extend(pantry)
	_key.resize(item.size())
	for row: int in item.size():
		_key[row] = _sort_key(pantry, row, hour_index)
	for row: int in range(1, item.size()):
		_sink(row)
	return item.size()


func extend(pantry: PantryScript) -> int:
	"""Append every (item, store) now present that the table does not list yet, in catalog order (see
	ORDER: the rows already listed keep their places). Returns how many were added."""
	var added: int = 0
	for it: int in Catalog.ITEM_COUNT:
		for at: int in pantry.storage.count():
			if is_present(pantry, it, at) and row_of(it, at) < 0:
				item.append(it)
				location.append(at)
				added += 1
	return added


func row_of(it: int, at: int) -> int:
	"""The row listing `it` at store `at`, or -1 when none does."""
	for row: int in item.size():
		if item[row] == it and location[row] == at:
			return row
	return -1


static func is_present(pantry: PantryScript, it: int, at: int) -> bool:
	"""Whether store `at` holds some of `it` or has a harvest of it incoming."""
	return pantry.milli_at(it, at) > 0 or pantry.incoming_milli(it, at) > 0


func _sort_key(pantry: PantryScript, row: int, hour_index: int) -> int:
	"""Soon rows by their hours (0..SOON_HOURS); every other row after them, in its listed order."""
	if spoil_hours_into(pantry, row, hour_index, _read) and _read.value <= SOON_HOURS:
		return _read.value
	return SOON_HOURS + 1 + row


func _sink(row: int) -> void:
	"""One insertion-sort step: move `row` up past every row with a larger key (stable)."""
	var k: int = row
	while k > 0 and _key[k - 1] > _key[k]:
		var held: Vector3i = Vector3i(_key[k - 1], item[k - 1], location[k - 1])
		_key[k - 1] = _key[k]
		item[k - 1] = item[k]
		location[k - 1] = location[k]
		_key[k] = held.x
		item[k] = held.y
		location[k] = held.z
		k -= 1


func spoil_hours_into(pantry: PantryScript, row: int, hour_index: int, out: IntMath.IntResult) -> bool:
	"""Calendar hours until the row's first lot spoils, into `out`; refuses NO_STOCK with nothing there."""
	if not pantry.first_to_spoil_at_into(item[row], location[row], hour_index, out):
		return false
	return out.succeed(pantry.lot_spoil_hours(out.value, hour_index))


func is_soon(pantry: PantryScript, row: int, hour_index: int) -> bool:
	"""Whether the row's first lot spoils within SOON_HOURS."""
	return spoil_hours_into(pantry, row, hour_index, _read) and _read.value <= SOON_HOURS


func available_text(pantry: PantryScript, row: int) -> String:
	"""What the row's store holds of its item ("0 U" once it has gone)."""
	return Text.units_text(pantry.milli_at(item[row], location[row]))


func incoming_text(pantry: PantryScript, row: int) -> String:
	"""What is on its way to the row's store, or a dash."""
	var milli: int = pantry.incoming_milli(item[row], location[row])
	return Text.units_text(milli) if milli > 0 else NONE_TEXT


func store_text(pantry: PantryScript, row: int) -> String:
	"""The row's store by name."""
	return pantry.storage.label_of(location[row])


func spoil_text(pantry: PantryScript, row: int, hour_index: int) -> String:
	"""'all in 6d 16h' (the whole of it is one lot), '2.0 U in 3d 4h' (the first of several), with
	'Soon: ' before it within SOON_HOURS; a dash with nothing in store."""
	if not pantry.first_to_spoil_at_into(item[row], location[row], hour_index, _read):
		return NONE_TEXT
	var lot: int = _read.value
	var hours: int = pantry.lot_spoil_hours(lot, hour_index)
	var held: int = pantry.milli_at(item[row], location[row])
	var amount: String = "all" if pantry.lot_milli(lot) == held else Text.units_text(pantry.lot_milli(lot))
	return "%s%s in %s" % ["Soon: " if hours <= SOON_HOURS else "", amount, until_text(hours)]


static func until_text(hours: int) -> String:
	"""Game hours as days and hours: '20h', '2d', '7d 22h'."""
	if hours < 24:
		return "%dh" % hours
	if hours % 24 == 0:
		return "%dd" % (hours / 24)
	return "%dd %dh" % [hours / 24, hours % 24]


static func store_cells(pantry: PantryScript, at: int) -> PackedStringArray:
	"""One store's row: name, stored, reserved for harvests on their way, free, capacity and its ageing
	rate ('×0.35')."""
	var storage := pantry.storage
	var permille: int = storage.permille_of(at)
	return PackedStringArray([storage.label_of(at), Text.units_text(pantry.used_milli_of(at)),
		Text.units_text(pantry.reserved_milli_of(at)), Text.units_text(pantry.room_milli_of(at)),
		Text.units_text(storage.capacity_milli_of(at)), "×%d.%02d" % [permille / 1000, (permille % 1000) / 10]])


static func is_empty(pantry: PantryScript) -> bool:
	"""Whether no store holds anything and nothing is incoming (the empty state)."""
	for at: int in pantry.storage.count():
		if pantry.used_milli_of(at) > 0 or pantry.reserved_milli_of(at) > 0:
			return false
	return true


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
