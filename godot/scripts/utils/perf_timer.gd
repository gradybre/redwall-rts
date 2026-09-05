class_name PerfTimer
extends RefCounted
## Microsecond stopwatch used to hold systems to the budgets in CLAUDE.md.

var _start_usec: int = 0
var _last_usec: int = 0


func start() -> void:
	"""Open a measurement window."""
	_start_usec = Time.get_ticks_usec()


func stop() -> int:
	"""Close the window and return its duration in microseconds."""
	_last_usec = Time.get_ticks_usec() - _start_usec
	return _last_usec


func get_last_usec() -> int:
	"""Duration of the most recently closed window, in microseconds."""
	return _last_usec


func get_last_msec() -> float:
	"""Duration of the most recently closed window, in milliseconds."""
	return float(_last_usec) / 1000.0
