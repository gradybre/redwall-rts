extends RefCounted
## THE SOAK TEST'S HOURLY TABLE (decision 0921). One row a game hour, a fixed set of named integer columns, kept in ONE
## packed column sized for the whole run before the first row (`setup`), so the harness's own memory does not grow while
## it measures the village's. A row past the capacity is not kept and is counted (`dropped`).

var columns: PackedStringArray = PackedStringArray()
## Rows past the capacity, not kept.
var dropped: int = 0
var _index: Dictionary = {}
var _rows: PackedInt64Array = PackedInt64Array()
var _width: int = 0
var _capacity: int = 0
var _count: int = 0


func setup(names: PackedStringArray, row_capacity: int) -> void:
	"""Name the columns and size the table for `row_capacity` rows (all zero), once, before the first row."""
	columns = names
	_width = names.size()
	_capacity = maxi(row_capacity, 0)
	_index.clear()
	for k: int in _width:
		_index[names[k]] = k
	_rows.resize(_width * (_capacity + 1))
	_rows.fill(0)
	_count = 0
	dropped = 0


func column(name: String) -> int:
	"""The index of column `name` (-1: none)."""
	return _index.get(name, -1)


func set_value(at: int, amount: int) -> void:
	"""Set column `at` of the row being filled (the slot after the last kept row; an unknown column is ignored)."""
	if at >= 0 and at < _width:
		_rows[_count * _width + at] = amount


func commit() -> bool:
	"""Keep the row being filled; false (and counted in `dropped`) when the table is full."""
	if _count >= _capacity:
		dropped += 1
		for k: int in _width:
			_rows[_count * _width + k] = 0
		return false
	_count += 1
	return true


func row_count() -> int:
	"""How many rows are kept."""
	return _count


func capacity() -> int:
	"""How many rows the table holds."""
	return _capacity


func value(row: int, at: int) -> int:
	"""Row `row`'s value in column `at`."""
	return _rows[row * _width + at]


func series(at: int) -> PackedInt64Array:
	"""Column `at` over every kept row (a copy)."""
	var out := PackedInt64Array()
	out.resize(_count)
	for row: int in _count:
		out[row] = _rows[row * _width + at]
	return out


func rows_as_arrays() -> Array:
	"""Every kept row as an Array of ints (for the JSON)."""
	var out: Array = []
	for row: int in _count:
		out.append(Array(_rows.slice(row * _width, (row + 1) * _width)))
	return out
