extends RefCounted
## THE TABLE DRINK (decision 1733; Brendan's ruling of 2026-10-07 on the balance rerun's P2 (a): "Approve both"): the
## raspberry cordial is poured at every ordinary supper as a table drink, as DEC-007 rules drink is shown -- a table or
## feast drink, no intoxication, no effect on Shared Warmth, and no NP (a drink is never eaten: 1621 P4). Before this it
## was poured only at the regatta's feast and all of it spoiled (the balance rerun: 48-56 U a year).
##
## WHEN. A supper's event, once the kitchen publishes it (kitchen.gd THE MEAL FINALIZED: `finals`, by serial -- read
## as people_taps.gd reads them, so the kitchen gains no hook). A breakfast pours nothing. An OCCASION's supper (the
## regatta's feast) pours nothing here: the feast pours its own drinks (regatta_menu.gd THE FEAST'S DRINKS). The
## occasion's meal is told by the kitchen's `occasion_key`, noted each update while it is set, so a feast whose
## occasion is cleared before its event is published is still known.
##
## HOW MUCH. A feast's measure: a unit for every four who ate (ceil(diners/4) U; regatta_menu.gd `drink_need_milli`,
## §5.7's mead quantity), of the cordial nobody has set aside, the lots that spoil first first -- no more than there is.
## Nothing is poured for a supper nobody ate.

const KitchenScript := preload("res://demo/kitchen/kitchen.gd")
const MealRules := preload("res://demo/kitchen/meal_rules.gd")
const TakesScript := preload("res://demo/kitchen/ingredient_takes.gd")
const Catalog := preload("res://demo/farm/farm_catalog.gd")
const IntMath := preload("res://scripts/core/int_math.gd")

## How many recent occasion meals are remembered (a feast is one meal; two keeps a feast whose next is planned).
const OCCASIONS_KEPT: int = 2
const GUESTS_PER_UNIT: int = 4
const FREE: int = -1

var _kitchen: KitchenScript = null
## The kitchen's events already looked through (its `finals_published`), and the occasion meals noted.
var _last_final: int = 0
var _occasions: PackedInt32Array = PackedInt32Array()
var _read: IntMath.IntResult = IntMath.IntResult.new()
## THE BOOKS: cordial poured at suppers (milli-U), the suppers it was poured at, and those that had none to pour.
var poured_milli: int = 0
var pours: int = 0
var dry_suppers: int = 0


func bind(kitchen: KitchenScript) -> void:
	"""Pour at `kitchen`'s suppers from its next published event on."""
	_kitchen = kitchen
	_last_final = kitchen.finals_published if kitchen != null else 0
	_occasions.resize(OCCASIONS_KEPT)
	_occasions.fill(FREE)


func update() -> void:
	"""Note the occasion's meal, then pour at each supper the kitchen has published since the last look."""
	if _kitchen == null:
		return
	_note_occasion(_kitchen.occasion_key)
	if _kitchen.finals_published == _last_final:
		return
	for final: KitchenScript.MealFinal in _kitchen.finals:
		if final.serial > _last_final:
			_at_supper(final)
	_last_final = _kitchen.finals_published


func _note_occasion(key: int) -> void:
	"""Remember occasion meal `key` (FREE: none set), the oldest forgotten first."""
	if key == FREE or _occasions.has(key):
		return
	for k: int in range(OCCASIONS_KEPT - 1, 0, -1):
		_occasions[k] = _occasions[k - 1]
	_occasions[0] = key


func _at_supper(final: KitchenScript.MealFinal) -> void:
	"""Pour at the published meal `final` when it is an ordinary supper somebody ate (see WHEN and HOW MUCH)."""
	if final.key % 2 != MealRules.MEAL_SUPPER or _occasions.has(final.key) or final.diners.is_empty():
		return
	var milli: int = mini(need_milli(final.diners.size()), _kitchen.takes.free_milli_of_crop(_kitchen.pantry,
		Catalog.CAT_CORDIAL))
	var poured: int = _pour(milli) if milli > 0 else 0
	if poured <= 0:
		dry_suppers += 1
		return
	poured_milli += poured
	pours += 1


static func need_milli(diners: int) -> int:
	"""A supper's measure: a unit for every four who ate (ceil(diners/4) U), milli-U."""
	@warning_ignore("integer_division") var units: int = (maxi(diners, 0) + GUESTS_PER_UNIT - 1) / GUESTS_PER_UNIT
	return units * 1000


func _pour(milli: int) -> int:
	"""Withdraw `milli` of free cordial, the lots that spoil first first, through a take of its own. What was poured."""
	var takes: TakesScript = _kitchen.takes
	var take: int = takes.new_take()
	var hour: int = _kitchen.hour_index()
	if not takes.reserve_into(_kitchen.pantry, take, Catalog.CAT_CORDIAL, milli, hour, _read) or _read.value <= 0:
		takes.release(take)
		return 0
	var held: int = _read.value
	var poured: int = held if takes.consume_into(_kitchen.pantry, take, held, TakesScript.AT_STORE, hour, _read,
		Catalog.CAT_CORDIAL) else 0
	takes.release(take)
	return poured
