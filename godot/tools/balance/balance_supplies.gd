extends RefCounted
## THE BALANCE HARNESS'S SUPPLIES WATCH (decision 1731): the hearths' wood and the apiary's honey, from the counters
## their owners keep for this purpose. Measurement only, read once at each day's close.
##
## WHERE EACH FIGURE COMES FROM -- cumulative counters only a committed change moves:
##   hearths  hearth_fuel.gd's THE METRICS "the balance sim reads" (decision 0571): `burned_milli` (all wood burned in
##            hearths), `heated_hours` and `cold_hours` (source-hours HEATED and OUT of fuel), each day's movement;
##            `fuel_days_hundredths()` (the HUD's heating fuel-days) at the close, as `_min` and `_end`, written only
##            while heat is demanded (its NO_DEMAND, -1, is left out, so a season's figures are its heated days'); the
##            hall's tier at the close (hall_projects.gd `tier`: the hall burns at x0.75 once it is 2, decision 1652);
##   apiary   apiary_model.gd's books (decision 1601) -- honey made = in the hives + released to the baskets + put by as
##            winter feed from the hive + lost to wildlife; feed put by (from the hive and from the pantry) = feed in
##            the hives + eaten by the bees; wax made; missed service days -- each day's movement; the weakest hive's
##            strength, the honey and the feed in the hives at the close; the days any hive stood abandoned.
## Every part may be missing (null): it then reads nothing.

const FuelScript := preload("res://demo/winter/hearth_fuel.gd")
const ApiaryScript := preload("res://demo/hives/apiary_model.gd")
const HallProjectsScript := preload("res://demo/hall/hall_projects.gd")

const F_BURNED: int = 0
const F_HEATED: int = 1
const F_COLD: int = 2
const F_HONEY_MADE: int = 3
const F_RELEASED: int = 4
const F_FED_FROM_PANTRY: int = 5
const F_EATEN: int = 6
const F_LOST: int = 7
const F_WAX_MADE: int = 8
const F_MISSED: int = 9
const F_FED_FROM_HIVE: int = 10
const F_COUNT: int = 11

var _fuel: FuelScript = null
var _apiary: ApiaryScript = null
var _hall: HallProjectsScript = null
## The counters as they stood at the last close, and as read now (F_* order).
var _last: PackedInt64Array = PackedInt64Array()
var _now: PackedInt64Array = PackedInt64Array()


func bind(fuel: FuelScript, apiary: ApiaryScript, hall: HallProjectsScript) -> void:
	"""Watch these from their counters now (any may be null)."""
	_fuel = fuel
	_apiary = apiary
	_hall = hall
	_last.resize(F_COUNT)
	_now.resize(F_COUNT)
	_read_into(_last)


func _read_into(out: PackedInt64Array) -> void:
	"""Every cumulative counter now, in F_* order (0 for a missing part)."""
	out.fill(0)
	if _fuel != null:
		out[F_BURNED] = _fuel.burned_milli
		out[F_HEATED] = _fuel.heated_hours
		out[F_COLD] = _fuel.cold_hours
	if _apiary != null:
		out[F_HONEY_MADE] = _apiary.honey_made_milli
		out[F_RELEASED] = _apiary.released_milli
		out[F_FED_FROM_PANTRY] = _apiary.fed_from_pantry_milli
		out[F_EATEN] = _apiary.eaten_milli
		out[F_LOST] = _apiary.lost_milli
		out[F_WAX_MADE] = _apiary.wax_made_milli
		out[F_MISSED] = _apiary.missed_days
		out[F_FED_FROM_HIVE] = _apiary.fed_from_hive_milli


func _moved(field: int) -> int:
	"""Counter `field`'s movement since the last close (read by `close_day` after `_read_into(_now)`)."""
	return _now[field] - _last[field]


func close_day() -> Dictionary:
	"""The day's hearth and apiary figures, then the counters rebased."""
	_read_into(_now)
	var out: Dictionary = {"hearths": _hearths(), "apiary": _apiary_day()}
	_last = _now.duplicate()
	return out


func _hearths() -> Dictionary:
	"""The hearths' day: wood burned (milli-U), source-hours heated and out of fuel, the hall's tier now, and the
	fuel-days now while heat is demanded (left out otherwise: see WHERE EACH FIGURE COMES FROM)."""
	var out: Dictionary = {"burned_milli": _moved(F_BURNED), "heated_hours": _moved(F_HEATED),
		"cold_hours": _moved(F_COLD), "hall_tier_end": _hall.tier if _hall != null else 0}
	var days: int = _fuel.fuel_days_hundredths() if _fuel != null else -1
	if days >= 0:
		out["fuel_days_hundredths_min"] = days
		out["fuel_days_hundredths_end"] = days
	return out


func _apiary_day() -> Dictionary:
	"""The apiary's day: its books' movements (milli-U, days), the weakest hive and the honey in the hives now."""
	return {"honey_made_milli": _moved(F_HONEY_MADE), "released_milli": _moved(F_RELEASED),
		"fed_from_hive_milli": _moved(F_FED_FROM_HIVE), "fed_from_pantry_milli": _moved(F_FED_FROM_PANTRY),
		"eaten_milli": _moved(F_EATEN), "lost_milli": _moved(F_LOST),
		"wax_made_milli": _moved(F_WAX_MADE), "missed_days": _moved(F_MISSED),
		"strength_min": _weakest(), "strength_end": _weakest(), "honey_in_hives_end": _sum_hives(true),
		"feed_in_hives_end": _sum_hives(false), "abandoned": _any_abandoned()}


func _weakest() -> int:
	"""The weakest hive's strength now (0..10000; -1 with no apiary)."""
	if _apiary == null:
		return -1
	var least: int = -1
	for a: int in _apiary.hive_ref.size():
		var s: int = _apiary.strength(a)
		least = s if least < 0 else mini(least, s)
	return least


func _sum_hives(honey: bool) -> int:
	"""Honey (`honey`) or winter feed held in every hive now, milli-U."""
	var milli: int = 0
	if _apiary != null:
		for a: int in _apiary.hive_ref.size():
			milli += _apiary.honey_in_hive(a) if honey else _apiary.feed(a)
	return milli


func _any_abandoned() -> bool:
	"""Whether any hive stands abandoned now."""
	if _apiary != null:
		for a: int in _apiary.hive_ref.size():
			if _apiary.is_abandoned(a):
				return true
	return false
