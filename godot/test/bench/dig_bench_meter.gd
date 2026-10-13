extends RefCounted
## Decision 1951: the dig-tick benchmark's meter. Per-series microsecond samples (per fixed tick, or per one-tick
## event such as a phase START), nearest-rank percentiles, and an optional per-tick state trace that proves two
## code revisions behave identically tick for tick. Harness only: it never runs in the game or in the suite.

## Written when set: one `tick sha256` line per traced tick, then the event lines.
const TRACE_ENV: String = "REDWALL_DIG_TRACE"
## Written when set: the report lines, appended, so several benchmark suites can share one file.
const REPORT_ENV: String = "REDWALL_DIG_REPORT"
const PERCENTILES: PackedInt32Array = [50, 95, 99]

var _series: Dictionary = {} # StringName -> PackedInt64Array of microseconds.
var _order: Array[StringName] = []
var _trace: PackedStringArray = PackedStringArray()
var _tracing: bool = OS.get_environment(TRACE_ENV) != ""


func add(series: StringName, usec: int) -> void:
	"""Append one sample to a series, creating it on first use (report order is first-use order)."""
	if not _series.has(series):
		_series[series] = PackedInt64Array()
		_order.append(series)
	var samples: PackedInt64Array = _series[series]
	samples.append(usec)
	_series[series] = samples


func samples(series: StringName) -> PackedInt64Array:
	"""A copy of one series; empty when it never received a sample."""
	return (_series[series] as PackedInt64Array).duplicate() if _series.has(series) else PackedInt64Array()


static func percentile(values: PackedInt64Array, rank: int) -> int:
	"""Nearest-rank percentile of `values` (0 when empty)."""
	if values.is_empty(): return 0
	var sorted: PackedInt64Array = values.duplicate()
	sorted.sort()
	@warning_ignore("integer_division")
	var index: int = maxi(0, (rank * sorted.size() + 99) / 100 - 1)
	return sorted[mini(index, sorted.size() - 1)]


func report(label: String) -> PackedStringArray:
	"""One `DIG-BENCH` line per series: n, p50, p95, p99, max and sum in microseconds."""
	var lines: PackedStringArray = PackedStringArray()
	for series: StringName in _order:
		var values: PackedInt64Array = _series[series]
		var total: int = 0
		var most: int = 0
		for value: int in values:
			total += value
			most = maxi(most, value)
		lines.append("DIG-BENCH %s %s n=%d p50=%d p95=%d p99=%d max=%d sum=%d" % [label, series, values.size(),
			percentile(values, 50), percentile(values, 95), percentile(values, 99), most, total])
	return lines


func emit(label: String, header: String) -> void:
	"""Print the report, and append it to REDWALL_DIG_REPORT when set."""
	var lines: PackedStringArray = report(label)
	lines.insert(0, "DIG-BENCH %s %s" % [label, header])
	for line: String in lines: print(line)
	var path: String = OS.get_environment(REPORT_ENV)
	if path == "": return
	var file: FileAccess = FileAccess.open(path, FileAccess.READ_WRITE if FileAccess.file_exists(path) else FileAccess.WRITE)
	if file == null: return
	file.seek_end()
	for line: String in lines: file.store_line(line)
	file.close()


func tracing() -> bool:
	"""Whether this run records the per-tick state trace."""
	return _tracing


func trace(tick: int, images: Array[PackedByteArray]) -> void:
	"""One trace line: the tick and the SHA-256 over every image, each prefixed by its size."""
	if not _tracing: return
	var context: HashingContext = HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	var size: PackedByteArray = PackedByteArray()
	size.resize(8)
	for image: PackedByteArray in images:
		size.encode_s64(0, image.size())
		context.update(size)
		if not image.is_empty(): context.update(image)
	_trace.append("%d %s" % [tick, context.finish().hex_encode()])


func trace_event(text: String) -> void:
	"""A non-tick trace line (an event's outcome), kept in order with the tick lines."""
	if _tracing: _trace.append(text)


func write_trace(label: String) -> void:
	"""Append the trace under a `# label` header to REDWALL_DIG_TRACE."""
	var path: String = OS.get_environment(TRACE_ENV)
	if path == "": return
	var file: FileAccess = FileAccess.open(path, FileAccess.READ_WRITE if FileAccess.file_exists(path) else FileAccess.WRITE)
	if file == null: return
	file.seek_end()
	file.store_line("# " + label)
	for line: String in _trace: file.store_line(line)
	file.close()
	_trace.clear()
