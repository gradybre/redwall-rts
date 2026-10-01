extends RefCounted
## THE BALANCE HARNESS'S ROLL-UP (decision 0911): days into seasons, and seasons into a run's totals, by one rule for
## every figure, so a new figure needs no new code. Pure functions over the day records the runner writes.
##
## THE RULE, by the field's name:
##   ends in "_min"   the smallest of the days' values;
##   ends in "_max"   the largest;
##   "end", or ends in "_end"   the last day's value;
##   "stock"          the last day's (it is a level, not a flow);
##   a number         summed;
##   a bool           how many days it was true;
##   a string         the distinct non-empty values, in order, joined by "+";
##   a dictionary     rolled up field by field (a key missing from a day counts as absent there);
##   an array         rolled up element by element (the per-resident rows).
## "day", "season", "year" and "season_day" are identity fields: the roll-up keeps the first day's.

const IDENTITY: Array[String] = ["day", "season", "year", "season_day"]
const LEVELS: Array[String] = ["stock"]


static func roll(days: Array) -> Dictionary:
	"""Every day of `days` (day records, dictionaries) rolled into one record by THE RULE."""
	var out: Dictionary = {}
	for record: Variant in days:
		_merge_into(out, record as Dictionary)
	out["days"] = days.size()
	return out


static func _merge_into(out: Dictionary, record: Dictionary) -> void:
	"""Fold one day's `record` into `out`."""
	for key: Variant in record:
		var field: String = String(key)
		var value: Variant = record[key]
		if not out.has(key):
			out[key] = _start(value)
		elif not field in IDENTITY:
			out[key] = _fold(field, out[key], value)


static func _start(value: Variant) -> Variant:
	"""A field's roll-up from its first value (a bool counts days true; containers are copied)."""
	if value is bool:
		return 1 if value else 0
	if value is Dictionary:
		var copy: Dictionary = {}
		_merge_into(copy, value as Dictionary)
		return copy
	if value is Array:
		var rows: Array = []
		for element: Variant in value:
			rows.append(_start(element))
		return rows
	return value


static func _fold(field: String, so_far: Variant, value: Variant) -> Variant:
	"""Fold `value` into `field`'s roll-up `so_far` (THE RULE)."""
	if field in LEVELS or field == "end" or field.ends_with("_end"):
		return _start(value)
	if value is bool:
		return int(so_far) + (1 if value else 0)
	if value is int:
		return _fold_int(field, int(so_far), int(value))
	if value is String:
		return _fold_text(String(so_far), String(value))
	if value is Dictionary and so_far is Dictionary:
		_merge_into(so_far as Dictionary, value as Dictionary)
		return so_far
	if value is Array and so_far is Array:
		return _fold_rows(so_far as Array, value as Array)
	return so_far


static func _fold_int(field: String, so_far: int, value: int) -> int:
	"""An integer field: min, max or sum by its name."""
	if field.ends_with("_min"):
		return mini(so_far, value)
	if field.ends_with("_max"):
		return maxi(so_far, value)
	return so_far + value


static func _fold_text(so_far: String, value: String) -> String:
	"""A text field: its distinct non-empty values joined by "+"."""
	if value.is_empty() or value in so_far.split("+"):
		return so_far
	return value if so_far.is_empty() else so_far + "+" + value


static func _fold_rows(so_far: Array, value: Array) -> Array:
	"""Arrays folded element by element (each a dictionary of figures)."""
	for k: int in mini(so_far.size(), value.size()):
		if so_far[k] is Dictionary and value[k] is Dictionary:
			_merge_into(so_far[k] as Dictionary, value[k] as Dictionary)
	return so_far


static func seasons(days: Array) -> Array:
	"""The days grouped by (year, season) in order, each group rolled up."""
	var out: Array = []
	var group: Array = []
	var current: int = -1
	for record: Variant in days:
		var d: Dictionary = record as Dictionary
		var key: int = int(d.get("year", 0)) * 4 + int(d.get("season", 0))
		if key != current and not group.is_empty():
			out.append(roll(group))
			group = []
		current = key
		group.append(d)
	if not group.is_empty():
		out.append(roll(group))
	return out
