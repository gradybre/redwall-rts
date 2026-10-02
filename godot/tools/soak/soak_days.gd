extends RefCounted
## THE SOAK TEST'S PER-DAY FRAME SAMPLES (decision 0921). Each measured frame adds one value per column (the frame's
## work and every system's time, microseconds) into buffers sized once for a day, so a twenty-day run keeps a day's
## frames, not twenty days', and allocates nothing a frame. `close_day` reduces the day to nearest-rank percentiles per
## column (scale_record.gd `summary`) and starts the next day. Frames past a day's capacity are not sampled and are
## counted (`dropped`).
##
## THE KEPT SUMMARIES live in one packed column sized for every day of the run (`setup`'s `days`), not in a Dictionary
## a day: a first twenty-day run kept them as Dictionaries, about 50 KB a day, and the harness's own summaries were
## then the steadiest growth in the process's static memory. `summary_of` builds a day's Dictionary for the JSON.

const RecordScript := preload("res://tools/scale_test/scale_record.gd")
## Per column and day: the summary's keys, in this order.
const STATS: PackedStringArray = ["n", "p50", "p95", "p99", "max", "mean"]

var columns: PackedStringArray = PackedStringArray()
var _buffers: Array[PackedInt32Array] = []
var _capacity: int = 0
var _count: int = 0
var _dropped: int = 0
var _row: PackedInt32Array = PackedInt32Array()
## Every closed day: [frames, dropped] then STATS per column (`_width` values a day).
var _kept: PackedInt64Array = PackedInt64Array()
var _width: int = 0
var _days_capacity: int = 0
var _days: int = 0
## Today's summary, reused (see THE KEPT SUMMARIES).
var _samples: PackedInt64Array = PackedInt64Array()


func setup(names: PackedStringArray, capacity: int, days: int = 1) -> void:
	"""Name the columns, size each day's buffers for `capacity` frames and the kept summaries for `days` days."""
	columns = names
	_capacity = maxi(capacity, 1)
	_buffers.clear()
	for k: int in names.size():
		var buffer := PackedInt32Array()
		buffer.resize(_capacity)
		_buffers.append(buffer)
	_row.resize(names.size())
	_row.fill(0)
	_samples.resize(_capacity)
	_width = 2 + names.size() * STATS.size()
	_days_capacity = maxi(days, 1)
	_kept.resize(_width * _days_capacity)
	_kept.fill(0)
	_count = 0
	_dropped = 0
	_days = 0


func set_value(at: int, usec: int) -> void:
	"""Set column `at` of the frame being filled (clamped to int32; an unknown column is ignored)."""
	if at >= 0 and at < _row.size():
		_row[at] = clampi(usec, 0, 2147483647)


func commit() -> void:
	"""Keep the frame being filled (or count it dropped when the day is full) and start the next at zero."""
	if _count < _capacity:
		for k: int in _row.size():
			_buffers[k][_count] = _row[k]
		_count += 1
	else:
		_dropped += 1
	_row.fill(0)


func frames() -> int:
	"""Frames sampled so far today."""
	return _count


func days_kept() -> int:
	"""How many closed days are kept."""
	return _days


func close_day() -> int:
	"""Reduce today to its summary, keep it (a day past the kept capacity is not kept) and start the next day; returns
	the day's index among those kept (-1: not kept)."""
	var at: int = _days if _days < _days_capacity else -1
	if at >= 0:
		var base: int = at * _width
		_kept[base] = _count
		_kept[base + 1] = _dropped
		for k: int in columns.size():
			_summarise(_buffers[k], base + 2 + k * STATS.size())
		_days += 1
	_count = 0
	_dropped = 0
	return at


func _summarise(buffer: PackedInt32Array, into: int) -> void:
	"""Today's samples of one column reduced to STATS at `_kept[into]`."""
	_samples.resize(_count)
	for at: int in _count:
		_samples[at] = buffer[at]
	var summary: Dictionary = RecordScript.summary(_samples)
	for s: int in STATS.size():
		_kept[into + s] = int(summary[STATS[s]])
	_samples.resize(_capacity)


func summary_of(day: int) -> Dictionary:
	"""Kept day `day`: {frames, dropped, columns: {name: {n, p50, p95, p99, max, mean}}}."""
	var base: int = day * _width
	var out: Dictionary = {"frames": _kept[base], "dropped": _kept[base + 1], "columns": {}}
	for k: int in columns.size():
		var stats: Dictionary = {}
		for s: int in STATS.size():
			stats[STATS[s]] = _kept[base + 2 + k * STATS.size() + s]
		out["columns"][columns[k]] = stats
	return out
