extends Logger
## THE SOAK TEST'S ERROR COUNTER (decision 0921). Registered with `OS.add_logger`, it hears every engine error, script
## error and warning the run prints (Godot 4.5+'s Logger; probed on 4.7.2), counts them by kind and keeps the first
## KEEP of each kind's text, so a twenty-day run can say "no errors" from inside rather than by reading its own log.
## The engine may call it from any thread: every member is read and written under `_lock`.

## How many messages of each kind are kept word for word.
const KEEP: int = 8

var _lock: Mutex = Mutex.new()
var _errors: int = 0
var _warnings: int = 0
var _first_errors: PackedStringArray = PackedStringArray()
var _first_warnings: PackedStringArray = PackedStringArray()


func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool,
		error_type: int, _script_backtrace: Array[ScriptBacktrace]) -> void:
	"""An engine or script error, or a warning: count it, and keep its text while fewer than KEEP are kept."""
	var text: String = "%s (%s:%d %s)" % [rationale if not rationale.is_empty() else code, file, line, function]
	_lock.lock()
	if error_type == ERROR_TYPE_WARNING:
		_warnings += 1
		if _first_warnings.size() < KEEP:
			_first_warnings.append(text)
	else:
		_errors += 1
		if _first_errors.size() < KEEP:
			_first_errors.append(("SCRIPT ERROR: " if error_type == ERROR_TYPE_SCRIPT else "ERROR: ") + text)
	_lock.unlock()


func _log_message(_message: String, _error: bool) -> void:
	"""Ordinary printed lines are not counted (errors arrive through `_log_error`)."""
	pass


func errors() -> int:
	"""Errors heard so far (engine, script and shader)."""
	_lock.lock()
	var out: int = _errors
	_lock.unlock()
	return out


func warnings() -> int:
	"""Warnings heard so far."""
	_lock.lock()
	var out: int = _warnings
	_lock.unlock()
	return out


func summary() -> Dictionary:
	"""{errors, warnings, first_errors, first_warnings}."""
	_lock.lock()
	var out: Dictionary = {"errors": _errors, "warnings": _warnings, "first_errors": _first_errors.duplicate(),
		"first_warnings": _first_warnings.duplicate()}
	_lock.unlock()
	return out
