extends RefCounted
## THE SOAK TEST'S IN-RUN GROWTH CHECK (decision 0921). The harness's own verdict over its hourly samples -- the one the
## one-day suite run asserts -- next to the fuller report tools/soak_report.py writes from the same JSON.
##
## For each watched column it fits a least-squares line to the samples from `skip` on (the first hours are warm-up:
## first meals, first night, caches filling) and states the growth PER GAME DAY (the slope times 24), the net change
## from the first kept sample to the last, and the fraction of hour-to-hour steps that went up. A column FAILS when its
## growth per day is above its tolerance AND its net change is too: a slope alone can come from a single late step, a
## net change alone from noise around a flat line.

## [column, tolerance per game day, why that tolerance]. Kilobytes or counts. These are a SHORT run's tolerances (the
## suite's one game day, decision 0921): loose enough for one day's noise and a restart's step, tight enough to catch
## what the soak found -- a whole cast kept alive by a reference cycle is about 4 300 objects and 3 MB a restart. The
## multi-day judgement, by daily floors, is tools/soak_report.py's (tools/soak_thresholds.json).
const TOLERANCES: Array = [
	["static_kb", 4096, "4 MB a day: a short run's floor still moves (a restart's new village, a first evening's songs)"],
	["objects", 500, "500 objects a day: a restart's new village differs by tens; a leaked cast is thousands"],
	["nodes", 20, "20 nodes a day: toasts and marks come and go; a lasting rise is a node not freed"],
	["resources", 20, "20 resources a day: everything the demo shows is loaded at boot (demo_prewarm.gd)"],
	["orphans", 1, "any lasting orphan node is a leak"],
]
const HOURS_PER_DAY: int = 24


static func slope(values: PackedInt64Array) -> float:
	"""The least-squares slope of `values` against their index (0 for fewer than two)."""
	var n: int = values.size()
	if n < 2:
		return 0.0
	var mean_x: float = float(n - 1) / 2.0
	var mean_y: float = 0.0
	for v: int in values:
		mean_y += float(v)
	mean_y /= float(n)
	var top: float = 0.0
	var bottom: float = 0.0
	for k: int in n:
		top += (float(k) - mean_x) * (float(values[k]) - mean_y)
		bottom += (float(k) - mean_x) * (float(k) - mean_x)
	return top / bottom


static func rising_share(values: PackedInt64Array) -> float:
	"""The fraction of steps between neighbours that went up (0 for fewer than two)."""
	if values.size() < 2:
		return 0.0
	var up: int = 0
	for k: int in values.size() - 1:
		if values[k + 1] > values[k]:
			up += 1
	return float(up) / float(values.size() - 1)


static func judge(name: String, values: PackedInt64Array, per_day_tolerance: float) -> Dictionary:
	"""One column's verdict over hourly `values`: {column, samples, per_day, net, rising, tolerance, fail}."""
	var per_day: float = slope(values) * float(HOURS_PER_DAY)
	var net: int = values[values.size() - 1] - values[0] if not values.is_empty() else 0
	var hours: float = maxf(float(values.size() - 1), 1.0)
	var allowed_net: float = per_day_tolerance * maxf(hours / float(HOURS_PER_DAY), 1.0)
	return {"column": name, "samples": values.size(), "per_day": snappedf(per_day, 0.01), "net": net,
		"rising": snappedf(rising_share(values), 0.01), "tolerance": per_day_tolerance,
		"fail": per_day > per_day_tolerance and float(net) > allowed_net}


static func check(table: Object, skip: int) -> Array:
	"""Every TOLERANCES column's verdict over `table`'s rows (soak_table.gd) from row `skip` on."""
	var out: Array = []
	for row: Array in TOLERANCES:
		var at: int = int(table.call(&"column", row[0]))
		if at < 0:
			continue
		var all: PackedInt64Array = table.call(&"series", at)
		var kept: PackedInt64Array = all.slice(mini(skip, all.size()))
		var verdict: Dictionary = judge(String(row[0]), kept, float(row[1]))
		verdict["why"] = row[2]
		out.append(verdict)
	return out


static func failures(verdicts: Array) -> PackedStringArray:
	"""One line per failing verdict."""
	var out := PackedStringArray()
	for verdict: Dictionary in verdicts:
		if bool(verdict["fail"]):
			out.append("%s grew %.1f a game day (net %d over %d samples; tolerance %s: %s)" % [verdict["column"],
				verdict["per_day"], verdict["net"], verdict["samples"], verdict["tolerance"], verdict["why"]])
	return out
