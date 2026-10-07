extends RefCounted
## THE WINTER IN WORDS: the HUD's Heating fuel cell (UI-SET-003), the fuel panel, the planner's Fuel lane, the
## notices and the residents' Chilled lines. Decision 0571. Static; formatting only -- every figure comes from
## hearth_fuel.gd, cold_exposure.gd or winter_rules.gd, and nothing here decides anything.

const Rules := preload("res://demo/winter/winter_rules.gd")
const FuelScript := preload("res://demo/winter/hearth_fuel.gd")
const ColdScript := preload("res://demo/winter/cold_exposure.gd")
const StoresScript := preload("res://demo/tunnel/tunnel_stores.gd")
const FarmText := preload("res://demo/farm/farm_text.gd")
const CalendarScript := preload("res://demo/demo_calendar.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")

## UI-SET-003's two states, and its caption.
const CAPTION: String = "Heating fuel"
const NO_DEMAND: String = "No current heat demand"
## The cell's own short no-demand value (the cell is 104-144 px; the full words are its tooltip and the ledger's).
const NO_DEMAND_SHORT: String = "No demand"
const HALL_NAME: String = "the hall"
const HALL_TITLE: String = "The hall"
const INFIRMARY_NAME: String = "the infirmary"
const INFIRMARY_TITLE: String = "The infirmary"
const FIREWOOD: String = "Firewood"
const CHILLED_WORD: String = "chilled"
const WORKS_AT: String = "works at %d%% until warmed through at a heated hearth"


static func days_value(hundredths: int) -> String:
	"""Fuel-days as the cell prints them: "1.6 days" (one decimal, floored), or the no-demand words."""
	if hundredths == Rules.NO_DEMAND:
		return NO_DEMAND
	return "%d.%d days" % [Rules.div(hundredths, 100), Rules.div(hundredths % 100, 10)]


static func cell_value(hundredths: int) -> String:
	"""The cell's value: the days, or its short no-demand words."""
	return NO_DEMAND_SHORT if hundredths == Rules.NO_DEMAND else days_value(hundredths)


static func hud_line(hundredths: int) -> String:
	"""UI-SET-003 in full: "Heating fuel: 1.6 days" or "Heating fuel: No current heat demand"."""
	return "%s: %s" % [CAPTION, days_value(hundredths)]


static func is_warning(hundredths: int) -> bool:
	"""UI §7's fuel warning state: under 2 days while heat is demanded."""
	return hundredths != Rules.NO_DEMAND and hundredths < Rules.WARN_FUEL_HUNDREDTHS


static func units(milli: int) -> String:
	"""Milli-U in the stores' words: "12.5 U"."""
	return StoresScript.units_text(maxi(milli, 0))


static func degrees(tenths: int) -> String:
	"""Tenths of a degree with the unit: "-5 °C", "3.5 °C"."""
	return "%s °C" % FarmText.degrees_text(tenths)


static func hour_text(hour_index: int) -> String:
	"""A calendar hour index as the demo's date: "Y1 Winter 3, 14:00"."""
	var day: int = Rules.day_of_hour(hour_index)
	var year: int = Rules.div(day, SimClock.DAYS_PER_SEASON * SimClock.SEASONS_PER_YEAR) + 1
	return "Y%d %s, %02d:00" % [year, CalendarScript.day_text(Rules.hour_season(hour_index),
		Rules.hour_season_day(hour_index)), Rules.hour_of_day(hour_index)]


static func source_name(source: int) -> String:
	"""A hearth's place: "Burrow home 2", "the hall", or "the infirmary"."""
	if source == FuelScript.INFIRMARY:
		return INFIRMARY_NAME
	return HALL_NAME if source == FuelScript.HALL else "Burrow home %d" % (source + 1)


static func source_title(source: int) -> String:
	"""A hearth's place, capitalised: "Burrow home 2", "The hall", "The infirmary"."""
	if source == FuelScript.INFIRMARY:
		return INFIRMARY_TITLE
	return HALL_TITLE if source == FuelScript.HALL else source_name(source)


static func names_of(sources: PackedInt32Array) -> String:
	"""Several places: "the hall, Burrow home 1"."""
	var out := PackedStringArray()
	for s: int in sources:
		out.append(source_name(s))
	return ", ".join(out)


static func state_line(fuel: FuelScript, source: int) -> String:
	"""One hearth's line: "Burrow home 1: heated, 18 °C" / "The hall: out of fuel since Y1 Winter 2, 03:00, 0.5 °C"."""
	var st: int = fuel.state[source]
	var words: String = FuelScript.STATE_WORDS[st]
	if st == FuelScript.STATE_OUT and fuel.out_since[source] >= 0:
		words += " since %s" % hour_text(fuel.out_since[source])
	return "%s: %s, %s" % [source_title(source), words, degrees(fuel.temperature_of(source))]


static func demand_line(fuel: FuelScript) -> String:
	"""Today's demand: "Burning 4.0 U a day: 1 hearth at 4.0 U, cooking 1.0 U (three-day mean)"; a tier-2 hearth is
	named at its own rate ("2 hearths at 4.0 U, the hall at 3.0 U", decision 1652)."""
	var hearths: int = fuel.burning_count()
	if fuel.heating_day_milli() <= 0:
		return "%s — %d %s, none needed today (%s mean)" % [NO_DEMAND, hearths, "hearth" if hearths == 1 else "hearths",
			degrees(fuel.day_mean_tenths)]
	return "Burning %s a day: %s, cooking %s (three-day mean)" % [units(fuel.heating_day_milli()
		+ fuel.cook_mean_milli()), hearths_words(fuel, fuel.day_rate_milli, false), units(fuel.cook_mean_milli())]


static func hearths_words(fuel: FuelScript, full_milli: int, winter: bool) -> String:
	"""The burning hearths at their rates: "2 hearths at 4.0 U" at the full rate `full_milli`, then each tier-2 hearth by
	name at its own ("the hall at 3.0 U"; `winter`: its winter rate, else today's). Allocates: words, never per frame."""
	var full: int = fuel.burning_count() - fuel.reduced_count()
	var parts := PackedStringArray()
	if full > 0:
		parts.append("%d %s at %s" % [full, "hearth" if full == 1 else "hearths", units(full_milli)])
	for s: int in FuelScript.SOURCES:
		if fuel.hearth[s] == 1 and fuel.banked[s] == 0 and fuel.tier[s] >= Rules.TIER_2:
			parts.append("%s at %s" % [source_name(s), units(fuel.winter_rate_of(s) if winter else fuel.rate_of(s))])
	return ", ".join(parts) if not parts.is_empty() else "0 hearths"


static func last_heated_line(fuel: FuelScript) -> String:
	"""REQ-SET-147's estimate: "Last heated hour: about Y1 Winter 4, 02:00", or "" with no demand."""
	var last: int = fuel.last_heated_hour()
	return "" if last < 0 else "Last heated hour: about %s" % hour_text(last)


static func projection_line(fuel: FuelScript) -> String:
	"""REQ-SET-114 / ruling 6: "Winter needs 60.0 U (12 days: 1 hearth at 4 U, cooking 1.0 U a day) — the stores hold
	40.0 U, 66%"."""
	var target: int = fuel.projection_milli()
	return "Winter needs %s (%d days: %s, cooking %s a day) — the stores hold %s, %d%%" % [units(target),
		Rules.PROJECTION_DAYS, hearths_words(fuel, Rules.WINTER_DAY_MILLI, true), units(fuel.cook_mean_milli()),
		units(fuel.wood_milli()), Rules.div(Rules.permille_of(fuel.wood_milli(), target), 10)]


static func warning_line(fuel: FuelScript, affected: PackedInt32Array) -> String:
	"""REQ-SET-147: under 2 fuel-days with the forecast below freezing -- the last heated hour and the homes."""
	return "Heating fuel for %s with frost forecast: the last heated hour is about %s — then %s go cold. Firewood is urgent" % [
		days_value(fuel.fuel_days_hundredths()), hour_text(maxi(fuel.last_heated_hour(), 0)), names_of(affected)]


static func out_line(out: PackedInt32Array, air_tenths: int) -> String:
	"""Out of fuel (REQ-SET-131): which hearths, and where their rooms are heading."""
	return "Out of fuel: %s %s no wood — %s cooling toward %s. Firewood is urgent (Work, J)" % [names_of(out),
		"has" if out.size() == 1 else "have", "its room is" if out.size() == 1 else "their rooms are", degrees(air_tenths)]


static func cold_home_line(source: int, tenths: int) -> String:
	"""A home gone cold: below freezing inside (the infirmary: its patients, decision 0995)."""
	if source == FuelScript.INFIRMARY:
		return "The infirmary has gone cold (%s): its patients build up exposure — bring in wood (Heating fuel, the top bar)" % \
			degrees(tenths)
	return "%s has gone cold (%s): sleepers there build up exposure — bring in wood, or move them to a heated home (Heating fuel, the top bar)" % [
		source_title(source), degrees(tenths)]


static func chilled_line(who: String, cold: ColdScript, i: int) -> String:
	"""A resident became Chilled, and why."""
	return "%s is Chilled: %s — %s" % [who, why(cold, i), WORKS_AT % Rules.div(Rules.CHILLED_WORK_PERMILLE, 10)]


static func warmed_line(who: String) -> String:
	"""A Chilled resident warmed through."""
	return "%s is warmed through and back to full pace" % who


static func why(cold: ColdScript, i: int) -> String:
	"""Why resident `i` is cold: "4.6 exposure-hours, last outdoors at -5 °C"."""
	return "%s exposure-hours, last %s at %s" % [tenths_text(cold.hours_tenths(i)), where_words(cold.place[i]),
		degrees(cold.place_tenths[i])]


static func where_words(place: int) -> String:
	"""Where a resident was, in words."""
	if place == ColdScript.OUTDOORS:
		return "outdoors"
	if place == ColdScript.BELOW:
		return "in the tunnels"
	return "in %s" % source_name(place)


static func tenths_text(tenths: int) -> String:
	"""Tenths as "4.6"."""
	return "%d.%d" % [Rules.div(tenths, 10), tenths % 10]


static func resident_text(cold: ColdScript, i: int, alone: bool) -> String:
	"""The party panel's cold line for resident `i`: alone, in full -- Chilled and why, or the exposure building; in a
	list only "chilled"; "" when it is warm."""
	if cold.is_chilled(i):
		return "Chilled — %s; %s" % [why(cold, i), WORKS_AT % Rules.div(Rules.CHILLED_WORK_PERMILLE, 10)] if alone \
			else CHILLED_WORD
	if alone and cold.cold_milli[i] > 0:
		return "Cold: %s exposure-hours (Chilled at %d) — %s" % [tenths_text(cold.hours_tenths(i)),
			Rules.div(Rules.CHILLED_AT_MILLI, Rules.MILLI), where_words(cold.place[i])]
	return ""


static func summary_line(food_days: String, fuel: FuelScript, warm_beds: int, beds: int, outdoors: int,
		residents: int) -> String:
	"""REQ-SET-149's preparation summary at the first winter."""
	return "Winter has come. Ready food: %s · %s · Warm beds: %d of %d · Working outdoors: %d of %d (below 0 °C they build up exposure)" % [
		food_days, hud_line(fuel.fuel_days_hundredths()), warm_beds, beds, outdoors, residents]
