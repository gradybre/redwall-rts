extends RefCounted
## Whole-column proofs for fixed-capacity column validators (ADR 1235).
##
## A column validator walks every row of a fixed-capacity table, and most of those rows are free
## and identical. Checked a cell at a time in GDScript that costs seconds per save (section 7's
## inventory alone was 8.7 s, Construction's image 0.2 s on every pass). The helpers here answer
## the same questions with the engine's native packed-array operations -- `count()`, `find()`,
## `slice()`, `sort()` and array equality -- plus a GDScript step per row that DIFFERS.
##
## They only ever PROVE. A validator that uses them runs its own row-by-row walk whenever a proof
## does not hold, so every refusal (its code, its detail and the first row it names) is exactly the
## row walk's. A proof that is too strict costs time, never correctness; one that is too lax would
## accept a bad image, so each helper states precisely what its `true` means.
##
## `rows_proven()` is the general one. For a validator whose verdict on a row depends ONLY on that
## row's cells (no other row, no row index), rows whose cells are identical get the same verdict.
## So it checks one pattern row, every row that differs from it in any column, and nothing else.
##
## NO FLOAT. ARCH-AUTH-002: there is no float in this file and there must never be one.

## Below this many rows a segment is scanned value by value instead of split again.
const SCAN_ROWS: int = 64


static func rows_proven(columns: Array, row_ok: Callable,
		extra_rows: PackedInt32Array = PackedInt32Array()) -> bool:
	"""True when `row_ok(row)` holds for every row of equally sized packed `columns`.

	Sound only for a row-local `row_ok` that reads nothing but these columns at `row` -- or other
	inputs whose differing rows the caller lists in `extra_rows` (see `strided_deviant_rows()`).
	It runs `row_ok` on the last row, on each row that differs from it in any column, and on
	every extra row.
	"""
	if columns.is_empty():
		return true
	var size: int = columns[0].size()
	for column: Variant in columns:
		if column.size() != size:
			return false
	if size == 0:
		return true
	var rows: PackedInt32Array = PackedInt32Array([size - 1])
	rows.append_array(extra_rows)
	for column: Variant in columns:
		_deviants_into(column, column[size - 1], 0, size, rows)
	return _rows_pass(rows, row_ok)


static func strided_deviant_rows(column: Variant, stride: int, rows: int,
		out: PackedInt32Array) -> bool:
	"""For a column holding `stride` cells per row, append every row with a cell that differs from
	the last row's. False (and nothing appended) when the last row's cells are not all one value,
	or the column is not `stride * rows` long, so the caller cannot rely on the list."""
	if stride <= 0 or column.size() != stride * rows or rows == 0:
		return false
	var value: int = column[column.size() - 1]
	if column.slice(column.size() - stride).count(value) != stride:
		return false
	var cells: PackedInt32Array = PackedInt32Array()
	_deviants_into(column, value, 0, column.size(), cells)
	for cell: int in cells:
		@warning_ignore("integer_division") out.append(cell / stride)
	return true


static func _rows_pass(rows: PackedInt32Array, row_ok: Callable) -> bool:
	"""True when `row_ok(row)` holds for every row of `rows`."""
	for row: int in rows:
		if not row_ok.call(row):
			return false
	return true


static func _deviants_into(column: Variant, value: int, from: int, to: int,
		out: PackedInt32Array) -> void:
	"""Append every index in `[from, to)` whose cell is not `value`, by native halving."""
	var segment: Variant = column.slice(from, to)
	if segment.count(value) == to - from:
		return
	if to - from <= SCAN_ROWS:
		for row: int in range(from, to):
			if column[row] != value:
				out.append(row)
		return
	@warning_ignore("integer_division") var middle: int = from + (to - from) / 2
	_deviants_into(column, value, from, middle, out)
	_deviants_into(column, value, middle, to, out)


static func bytes_are_flags(column: PackedByteArray) -> bool:
	"""True when every byte of `column` is 0 or 1."""
	return column.count(0) + column.count(1) == column.size()


static func rows_holding(column: PackedByteArray, value: int) -> PackedInt32Array:
	"""Every index whose byte equals `value`, ascending (one native `find()` per hit)."""
	var rows: PackedInt32Array = PackedInt32Array()
	var at: int = column.find(value)
	while at >= 0:
		rows.append(at)
		at = column.find(value, at + 1)
	return rows


static func i32_others_equal(column: PackedInt32Array, skip: PackedInt32Array, value: int) -> bool:
	"""True when every cell whose index is NOT in `skip` equals `value`."""
	var masked: PackedInt32Array = column.duplicate()
	for row: int in skip:
		masked[row] = value
	return masked.count(value) == masked.size()


static func i64_others_equal(column: PackedInt64Array, skip: PackedInt32Array, value: int) -> bool:
	"""True when every cell whose index is NOT in `skip` equals `value`."""
	var masked: PackedInt64Array = column.duplicate()
	for row: int in skip:
		masked[row] = value
	return masked.count(value) == masked.size()


static func u8_others_equal(column: PackedByteArray, skip: PackedInt32Array, value: int) -> bool:
	"""True when every cell whose index is NOT in `skip` equals `value` (0..255)."""
	var masked: PackedByteArray = column.duplicate()
	for row: int in skip:
		masked[row] = value
	return masked.count(value) == masked.size()


static func i32_minimum(column: PackedInt32Array) -> int:
	"""The smallest cell of a nonempty column (a native sort of a copy); 0 when empty."""
	if column.is_empty():
		return 0
	var sorted: PackedInt32Array = column.duplicate()
	sorted.sort()
	return sorted[0]


static func i64_minimum(column: PackedInt64Array) -> int:
	"""The smallest cell of a nonempty column (a native sort of a copy); 0 when empty."""
	if column.is_empty():
		return 0
	var sorted: PackedInt64Array = column.duplicate()
	sorted.sort()
	return sorted[0]


static func ascending_except(capacity: int, excluded: PackedInt32Array) -> PackedInt32Array:
	"""`0..capacity-1` without the ascending, distinct, in-range indices of `excluded`."""
	var kept: PackedInt32Array = PackedInt32Array()
	var start: int = 0
	for row: int in excluded:
		kept.append_array(_ascending(start, row))
		start = row + 1
	kept.append_array(_ascending(start, capacity))
	return kept


static func _ascending(from: int, to: int) -> PackedInt32Array:
	"""`from..to-1` as one column, built natively from `range()`."""
	if to <= from:
		return PackedInt32Array()
	return PackedInt32Array(range(from, to))


static func is_permutation_of(prefix: PackedInt32Array, expected_sorted: PackedInt32Array) -> bool:
	"""True when `prefix` holds exactly the values of the ascending, distinct `expected_sorted`."""
	if prefix.size() != expected_sorted.size():
		return false
	var sorted: PackedInt32Array = prefix.duplicate()
	sorted.sort()
	return sorted == expected_sorted
