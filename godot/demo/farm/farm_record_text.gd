extends RefCounted
## The after-action record's words (decision 0451): a closed day's line for the village news and the planner's Record
## tab, a season's totals, and the table's cells. Pure functions of farm_record.gd; every quantity through farm_text.gd's
## one formatter (`units_text`, decision 0222).

const RecordScript := preload("res://demo/farm/farm_record.gd")
const Catalog := preload("res://demo/farm/farm_catalog.gd")
const Text := preload("res://demo/farm/farm_text.gd")
const CalendarScript := preload("res://demo/demo_calendar.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")

## "Spoiled" is food spoiled in store and portions spoiled on the table; a cancelled batch's spoiled food was already
## withdrawn (in "Food used"), so only the day's line names it.
const TABLE_TITLES: Array[String] = ["Day", "Harvested", "Food used", "Portions eaten", "Spoiled", "Went without",
	"Crops lost"]
const TABLE_COLUMNS: int = 7


static func day_name(day: int) -> String:
	"""A calendar day index as the HUD names it: 'Spring 3' (and the year after the first: 'Y2 Spring 3')."""
	@warning_ignore("integer_division") var season: int = (day / SimClock.DAYS_PER_SEASON) % SimClock.SEASONS_PER_YEAR
	@warning_ignore("integer_division") var year: int = day / SimClock.DAYS_PER_YEAR + 1
	var name: String = CalendarScript.day_text(season, day % SimClock.DAYS_PER_SEASON + 1)
	return name if year == 1 else "Y%d %s" % [year, name]


static func season_name(absolute_season: int) -> String:
	"""'Spring, year 1'."""
	@warning_ignore("integer_division") return "%s, year %d" % [CalendarScript.SEASON_TITLES[absolute_season % SimClock.SEASONS_PER_YEAR],
		absolute_season / SimClock.SEASONS_PER_YEAR + 1]


static func day_line(record: RecordScript, k: int) -> String:
	"""Kept day `k` in full: what it produced, consumed, spoiled and missed."""
	var parts := PackedStringArray()
	parts.append("harvested %s%s" % [Text.units_text(record.value(k, RecordScript.F_HARVESTED)),
		_items(record, k, RecordScript.G_HARVESTED)])
	parts.append("food used %s (cooked %s, eaten raw %s)" % [Text.units_text(record.value(k, RecordScript.F_USED)),
		Text.units_text(record.value(k, RecordScript.F_COOKED)), Text.units_text(record.value(k, RecordScript.F_RAW))])
	parts.append("%d portions eaten" % record.value(k, RecordScript.F_PORTIONS))
	parts.append(_spoiled_words(record.value(k, RecordScript.F_SPOILED), record.value(k, RecordScript.F_PORTIONS_SPOILED),
		record.value(k, RecordScript.F_KITCHEN_SPOILED)))
	parts.append("missed: " + _missed_words(record.value(k, RecordScript.F_WITHOUT), record.value(k, RecordScript.F_LOST),
		record.value(k, RecordScript.F_LOST_BEDS)))
	return "Day's record, %s: %s" % [day_name(record.value(k, RecordScript.F_DAY)), " · ".join(parts)]


static func day_summary(record: RecordScript, k: int) -> String:
	"""Kept day `k` in one short line, for the news strip: 'Spring 3's record: +5.1 U harvested · 16 portions eaten · 1
	went without'."""
	var line: String = "%s's record: +%s harvested · %d portions eaten" % [day_name(record.value(k, RecordScript.F_DAY)),
		Text.units_text(record.value(k, RecordScript.F_HARVESTED)), record.value(k, RecordScript.F_PORTIONS)]
	var without: int = record.value(k, RecordScript.F_WITHOUT)
	var lost: int = record.value(k, RecordScript.F_LOST)
	if without > 0:
		line += " · %d went without" % without
	if lost > 0:
		line += " · %d crop%s lost" % [lost, "" if lost == 1 else "s"]
	return line


static func season_line(record: RecordScript, absolute_season: int) -> String:
	"""A season's totals over its kept days: 'Spring, year 1 (12 days): harvested 40.2 U · ...'."""
	var days: int = record.season_days(absolute_season)
	if days == 0:
		return "%s: no day of it has closed yet." % season_name(absolute_season)
	var parts := PackedStringArray()
	parts.append("harvested %s" % Text.units_text(record.season_total(absolute_season, RecordScript.F_HARVESTED)))
	parts.append("food used %s" % Text.units_text(record.season_total(absolute_season, RecordScript.F_USED)))
	parts.append("%d portions eaten" % record.season_total(absolute_season, RecordScript.F_PORTIONS))
	parts.append(_spoiled_words(record.season_total(absolute_season, RecordScript.F_SPOILED), record.season_total(
		absolute_season, RecordScript.F_PORTIONS_SPOILED), record.season_total(absolute_season, RecordScript.F_KITCHEN_SPOILED)))
	parts.append("missed: " + _missed_words(record.season_total(absolute_season, RecordScript.F_WITHOUT),
		record.season_total(absolute_season, RecordScript.F_LOST), 0))
	return "%s (%d day%s): %s" % [season_name(absolute_season), days, "" if days == 1 else "s", " · ".join(parts)]


static func table_cells_into(record: RecordScript, k: int, out: PackedStringArray) -> void:
	"""Kept day `k`'s cells, TABLE_TITLES order."""
	out.resize(TABLE_COLUMNS)
	out[0] = day_name(record.value(k, RecordScript.F_DAY))
	out[1] = Text.units_text(record.value(k, RecordScript.F_HARVESTED))
	out[2] = Text.units_text(record.value(k, RecordScript.F_USED))
	out[3] = "%d" % record.value(k, RecordScript.F_PORTIONS)
	out[4] = "%s · %d portions" % [Text.units_text(record.value(k, RecordScript.F_SPOILED)),
		record.value(k, RecordScript.F_PORTIONS_SPOILED)]
	out[5] = "%d" % record.value(k, RecordScript.F_WITHOUT)
	out[6] = "%d" % record.value(k, RecordScript.F_LOST)


static func _items(record: RecordScript, k: int, group: int) -> String:
	"""' (carrot 5.1 U, radish 2.0 U)' -- the items a group moved that day ('' for none)."""
	var parts := PackedStringArray()
	for item: int in Catalog.PANTRY_ITEM_COUNT:
		var milli: int = record.item_value(k, group, item)
		if milli > 0:
			parts.append("%s %s" % [Catalog.ITEM_LABELS[item].to_lower(), Text.units_text(milli)])
	return " (%s)" % ", ".join(parts) if not parts.is_empty() else ""


static func _spoiled_words(in_store: int, portions: int, kitchen_milli: int) -> String:
	"""'spoiled 1.2 U in store, 2 portions' (and a cancelled batch's spoiled food)."""
	var words: String = "spoiled %s in store, %d portion%s" % [Text.units_text(in_store), portions,
		"" if portions == 1 else "s"]
	if kitchen_milli > 0:
		words += ", %s from a cancelled batch" % Text.units_text(kitchen_milli)
	return words


static func _missed_words(without: int, lost: int, lost_beds: int) -> String:
	"""'1 went without, 1 crop lost (bed 3)' or 'nothing'."""
	var parts := PackedStringArray()
	if without > 0:
		parts.append("%d went without a meal" % without)
	if lost > 0:
		parts.append("%d crop%s lost%s" % [lost, "" if lost == 1 else "s", _beds(lost_beds)])
	return ", ".join(parts) if not parts.is_empty() else "nothing"


static func _beds(mask: int) -> String:
	"""' (bed 3, bed 5)' from a bed bit mask ('' for none)."""
	var parts := PackedStringArray()
	for bed: int in Catalog.BED_COUNT:
		if mask & (1 << bed):
			parts.append("bed %d" % (bed + 1))
	return " (%s)" % ", ".join(parts) if not parts.is_empty() else ""
