extends RefCounted
## THE SCALE TEST'S SAMPLES AND THEIR STATISTICS (decision 0561). One row a frame, a fixed set of integer columns
## (microseconds, kilobytes or counts, named by the harness before the first row), kept in one flat packed column so a
## long run costs a few megabytes and no per-frame allocation. `stats` reduces a column over a row filter to
## p50/p95/p99/max/mean; `write_csv` dumps every row for a closer look.

var columns: PackedStringArray = PackedStringArray()
var _index: Dictionary = {}
var _rows: PackedInt64Array = PackedInt64Array()
var _row: PackedInt64Array = PackedInt64Array()
var _count: int = 0


func define(names: PackedStringArray) -> void:
	"""Name the columns (once, before the first row)."""
	columns = names
	_index.clear()
	for k: int in names.size():
		_index[names[k]] = k
	_row.resize(names.size())
	_row.fill(0)


func column(name: String) -> int:
	"""The index of column `name` (-1: none)."""
	return _index.get(name, -1)


func set_value(at: int, amount: int) -> void:
	"""Set column `at` in the row being filled."""
	if at >= 0:
		_row[at] = amount


func commit() -> void:
	"""Keep the row being filled and start the next one at zero."""
	_rows.append_array(_row)
	_row.fill(0)
	_count += 1


func row_count() -> int:
	"""How many rows are kept."""
	return _count


func value(row: int, at: int) -> int:
	"""Row `row`'s value in column `at`."""
	return _rows[row * columns.size() + at]


func values(at: int, keep: Callable) -> PackedInt64Array:
	"""Column `at` over the rows `keep(row) -> bool` keeps."""
	var out := PackedInt64Array()
	for row: int in _count:
		if keep.call(row):
			out.append(value(row, at))
	return out


static func summary(samples: PackedInt64Array) -> Dictionary:
	"""{n, p50, p95, p99, max, mean} of `samples` (nearest-rank percentiles; all 0 when empty)."""
	if samples.is_empty():
		return {"n": 0, "p50": 0, "p95": 0, "p99": 0, "max": 0, "mean": 0}
	var sorted := samples.duplicate()
	sorted.sort()
	var total: int = 0
	for v: int in sorted:
		total += v
	@warning_ignore("integer_division")
	var mean: int = total / sorted.size()
	return {"n": sorted.size(), "p50": _rank(sorted, 50), "p95": _rank(sorted, 95), "p99": _rank(sorted, 99),
		"max": sorted[sorted.size() - 1], "mean": mean}


static func _rank(sorted: PackedInt64Array, percent: int) -> int:
	"""The nearest-rank `percent`th percentile of an ascending column."""
	var rank: int = ceili(float(percent) * float(sorted.size()) / 100.0)
	return sorted[clampi(rank - 1, 0, sorted.size() - 1)]


func stats(at: int, keep: Callable) -> Dictionary:
	"""`summary` of column `at` over the rows `keep` keeps."""
	return summary(values(at, keep))


func write_csv(path: String) -> bool:
	"""Every row, with a header, to `path`. False when the file cannot be written."""
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_line(",".join(columns))
	var width: int = columns.size()
	var line := PackedStringArray()
	line.resize(width)
	for row: int in _count:
		for k: int in width:
			line[k] = str(_rows[row * width + k])
		file.store_line(",".join(line))
	file.close()
	return true
