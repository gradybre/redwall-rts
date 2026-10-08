extends RefCounted
## THE BALANCE HARNESS'S SHORT CSV (decision 0911): one row a day of the headline figures, for a spreadsheet or a quick
## look. The JSON holds everything; this is a view of it. Each column is a path into the day record ("/"-separated);
## a number that is not there is written 0.

const COLUMNS: Array[String] = [
	"day", "year", "season", "season_day", "partial",
	"items_total/produced", "items_total/withdrawn", "items_total/spoiled",
	"kitchen/portions_eaten", "kitchen/cooked_milli", "kitchen/raw_eaten_milli", "kitchen/table_spoiled_portions",
	"stock/total_milli", "reserve_days_milli_min", "reserve_days_milli_end",
	"meals/ate", "meals/raw", "meals/without",
	"fed_resident_hours/fed", "fed_resident_hours/peckish", "fed_resident_hours/hungry",
	"labour_ticks/work", "labour_ticks/idle", "labour_ticks/meal", "labour_ticks/rest", "labour_ticks/other",
	"board/queue_max", "board/claimed", "board/dropped", "board/wait_ticks_sum", "board/wait_ticks_max",
	"materials/wood/in", "materials/wood/out", "materials/wood/end", "materials/planks/end",
	"materials/stone/end", "materials/earth/end",
	"weather/event", "weather/frost_night", "weather/blight_outbreak", "weather/air_tenths_min",
	"beds/sown", "beds/harvested", "beds/growing_end",
	"incidents/occurrences", "incidents/critical", "rescues",
	"hearths/burned_milli", "hearths/heated_hours", "hearths/cold_hours", "hearths/fuel_days_hundredths_end",
	"apiary/honey_made_milli", "apiary/released_milli", "apiary/fed_from_hive_milli", "apiary/strength_end",
]


static func of_days(days: Array) -> String:
	"""The header and one row per day record."""
	var lines: PackedStringArray = PackedStringArray([",".join(COLUMNS)])
	for record: Variant in days:
		var row: PackedStringArray = PackedStringArray()
		for column: String in COLUMNS:
			row.append(_cell(_at(record as Dictionary, column)))
		lines.append(",".join(row))
	return "\n".join(lines) + "\n"


static func _at(record: Dictionary, path: String) -> Variant:
	"""The value at `path` in `record` (the "items_total/<ledger>" columns sum that ledger's items); 0 when absent."""
	var parts: PackedStringArray = path.split("/")
	if parts[0] == "items_total":
		var items: Dictionary = (record.get("items", {}) as Dictionary).get(parts[1], {})
		var total: int = 0
		for key: Variant in items:
			total += int(items[key])
		return total
	var at: Variant = record
	for part: String in parts:
		if not at is Dictionary or not (at as Dictionary).has(part):
			return 0
		at = (at as Dictionary)[part]
	return at


static func _cell(value: Variant) -> String:
	"""A CSV cell: booleans as 1/0, text quoted (its quotes doubled) when it holds a comma or a quote."""
	if value is bool:
		return "1" if value else "0"
	var text: String = str(value)
	if not text.contains(",") and not text.contains("\""):
		return text
	return "\"%s\"" % text.replace("\"", "\"\"")
