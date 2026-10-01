extends Logger
## The playtest log's ERROR CAPTURE: an engine Logger (Godot 4.5+ `OS.add_logger`) that copies every error,
## warning, script error, shader error and `printerr` line into the session file (decision 0562). DEMO
## DIAGNOSTICS.
##
## WHAT IT SEES. `push_error` and `push_warning` (as ERROR_TYPE_ERROR / _WARNING, with the script frames that
## raised them), a GDScript runtime error (ERROR_TYPE_SCRIPT) and an engine `ERR_*` check, from any thread. Plain
## `print` is left to Godot's own godot.log beside it. Each line also becomes an error breadcrumb, so a freeze's
## dump shows the errors just before it.
##
## RELEASE EXPORTS (measured on the 4.7.2 macOS release template, the same engine code as Windows'): push_error
## and push_warning arrive with no script frames; an out-of-range index raises nothing at all, and a method called
## on null ends the process (signal 11) before any logger runs. A debug export reports both as SCRIPT ERRORs with
## frames and carries on. The breadcrumbs and the unclean-end check are what cover a release crash.
##
## FOLDING. The writer counts each distinct line (`note_repeat`): an error raised every frame is written
## REPEAT_LIMIT times and then only counted, and the heartbeat says how many were folded.
##
## NO CYCLE. It holds the writer and the ring, never the session that owns it.

const WriterScript := preload("res://demo/playtest/log_writer.gd")
const BreadcrumbsScript := preload("res://demo/playtest/breadcrumbs.gd")

const TYPE_WORDS: Array[String] = ["ERROR", "WARNING", "SCRIPT ERROR", "SHADER ERROR"]
const TYPE_PRINTERR: int = 4
## Script frames written per error.
const MAX_FRAMES: int = 6

var _writer: WriterScript = null
var _crumbs: BreadcrumbsScript = null
var _origin_usec: int = 0
## Errors and warnings seen (written or folded), by type: error, warning, script, shader, printerr.
var counts: PackedInt32Array = PackedInt32Array([0, 0, 0, 0, 0])
var _counts_mutex: Mutex = Mutex.new()


func _init(writer: WriterScript, crumbs: BreadcrumbsScript, origin_usec: int) -> void:
	"""Write to `writer`, and leave a breadcrumb in `crumbs`, with times from `origin_usec`."""
	_writer = writer
	_crumbs = crumbs
	_origin_usec = origin_usec


func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool,
		error_type: int, script_backtraces: Array[ScriptBacktrace]) -> void:
	"""An engine or script error or warning: one line with where it came from and its script frames."""
	var text: String = rationale if not rationale.is_empty() else code
	var where: String = "%s:%d in %s" % [file, line, function]
	report(error_type, text, where, frames_text(script_backtraces))


func _log_message(message: String, error: bool) -> void:
	"""A printed line: only `printerr` (stderr) is kept; `print` stays in godot.log."""
	if error:
		report(TYPE_PRINTERR, message.strip_edges(), "", "")


func report(kind: int, text: String, where: String, frames: String) -> void:
	"""Count, fold and write one captured line (also callable directly, which the tests do)."""
	var safe_kind: int = clampi(kind, 0, TYPE_PRINTERR)
	_counts_mutex.lock()
	counts[safe_kind] += 1
	var serial: int = counts[safe_kind]
	_counts_mutex.unlock()
	_crumbs.record_now(BreadcrumbsScript.KIND_ERROR, &"logged", safe_kind, serial)
	if not _writer.note_repeat("%d|%s|%s" % [safe_kind, text, where]):
		return
	var before := PackedStringArray()
	if _crumbs.drain_into(before) > 0:
		_writer.write("\n".join(before))
	_writer.write(format_line(Time.get_ticks_usec() - _origin_usec, safe_kind, text, where, frames))


static func format_line(usec: int, kind: int, text: String, where: String, frames: String) -> String:
	"""'+12.345s ERROR  text  (at file:line in function)' and, indented below, the script frames."""
	var word: String = TYPE_WORDS[kind] if kind < TYPE_WORDS.size() else "printerr"
	var out: String = "+%.3fs %s  %s" % [float(usec) / 1000000.0, word, text]
	if not where.is_empty():
		out += "  (at %s)" % where
	if not frames.is_empty():
		out += "\n" + frames
	return out


static func frames_text(backtraces: Array[ScriptBacktrace]) -> String:
	"""The first MAX_FRAMES script frames of each backtrace, one indented line each ('' for none)."""
	var out := PackedStringArray()
	for trace: ScriptBacktrace in backtraces:
		for k: int in mini(trace.get_frame_count(), MAX_FRAMES):
			out.append("      [%d] %s (%s:%d)" % [k, trace.get_frame_function(k), trace.get_frame_file(k),
				trace.get_frame_line(k)])
	return "\n".join(out)


func counts_snapshot() -> PackedInt32Array:
	"""A copy of `counts`, read under its lock (the logger's threads add to it)."""
	_counts_mutex.lock()
	var copy: PackedInt32Array = counts.duplicate()
	_counts_mutex.unlock()
	return copy


func total() -> int:
	"""Every captured line so far, of any type."""
	_counts_mutex.lock()
	var sum: int = 0
	for count: int in counts:
		sum += count
	_counts_mutex.unlock()
	return sum
