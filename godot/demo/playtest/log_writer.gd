extends RefCounted
## The playtest log's FILE: one session's lines, flushed to disk as they are written (decision 0562). DEMO
## DIAGNOSTICS.
##
## FLUSHED. Every `write` flushes, so a hard crash loses nothing already written. The callers batch (the
## breadcrumbs at most once a second, a heartbeat every HEARTBEAT seconds), so this is a handful of flushes a
## minute, not one a frame. Godot's own `godot.log` beside it is flushed only on error lines in a release export
## (`application/run/flush_stdout_on_print` is off there), which is why the session keeps its own file.
##
## CAPPED. A session writes at most MAX_BYTES; past that only a FORCED line (a mark, a freeze, the end of the
## session) is written, into a RESERVE_BYTES reserve, and the rest are counted as dropped. One "log capped" line
## says so. Repeated errors are folded before they get here (`note_repeat`): the first REPEAT_LIMIT of each kind
## are written, the rest only counted.
##
## TAIL. The last TAIL_LINES lines stay in memory for Copy report, so the report never reopens the file.
##
## PRIVACY. `scrub` replaces the user's home and user-data folders with '~' and '<user data>' in every line, so a
## report carries no account name from a path.
##
## THREADS. The logger and the freeze watch write from other threads: everything holds the mutex. A write
## that raises an engine error re-enters through the logger; `_busy` drops that inner line instead of recursing.

const MAX_KIB: int = 2048
const MAX_BYTES: int = MAX_KIB * 1024
const RESERVE_BYTES: int = 64 * 1024
const TAIL_LINES: int = 200
## Each distinct error or warning is written this many times; later repeats are counted.
const REPEAT_LIMIT: int = 5
## At most this many distinct repeat keys are tracked; past it every line counts as new (and the cap holds).
const MAX_REPEAT_KEYS: int = 512
const CAPPED_LINE: String = "== log capped at %d KiB: later lines are dropped (marks, freezes and the end still written)"

var _file: FileAccess = null
var _path: String = ""
var _bytes: int = 0
var _dropped: int = 0
var _capped: bool = false
var _busy: bool = false
var _tail: PackedStringArray = PackedStringArray()
var _tail_next: int = 0
var _tail_count: int = 0
var _repeats: Dictionary = {}
var _suppressed: int = 0
var _scrub_from: PackedStringArray = PackedStringArray()
var _scrub_to: PackedStringArray = PackedStringArray()
var _mutex: Mutex = Mutex.new()


func _init() -> void:
	"""The tail ring, sized once."""
	_tail.resize(TAIL_LINES)


func open(file_path: String) -> bool:
	"""Create (or truncate) the session's file. False when it cannot be written."""
	_mutex.lock()
	_file = FileAccess.open(file_path, FileAccess.WRITE)
	_path = file_path
	_bytes = 0
	_mutex.unlock()
	return _file != null


func is_open() -> bool:
	"""Whether the file is open for writing."""
	return _file != null


func path() -> String:
	"""The session file's path (user://...)."""
	return _path


func add_scrub(from: String, to: String) -> void:
	"""Replace `from` with `to` in every later line (a home or user-data folder; ignored when shorter than three
	characters). Longer folders are replaced first, so the user-data folder inside the home folder keeps its name."""
	if from.length() < 3:
		return
	_mutex.lock()
	var at: int = 0
	while at < _scrub_from.size() and _scrub_from[at].length() >= from.length():
		at += 1
	_scrub_from.insert(at, from)
	_scrub_to.insert(at, to)
	_mutex.unlock()


func scrub(text: String) -> String:
	"""`text` with every scrubbed folder replaced (both slash directions)."""
	var out: String = text
	for k: int in _scrub_from.size():
		var from: String = _scrub_from[k]
		out = out.replace(from.replace("\\", "/"), _scrub_to[k]).replace(from.replace("/", "\\"), _scrub_to[k])
	return out


func write(text: String, forced: bool = false) -> bool:
	"""Write one line (or several, newline-joined) and flush. `forced` lines may use the reserve past the cap.
	False when the line was dropped (no file, past the cap, or written from inside a write)."""
	_mutex.lock()
	if _busy:
		_mutex.unlock()
		return false
	_busy = true
	var written: bool = _write_locked(scrub(text), forced)
	_busy = false
	_mutex.unlock()
	return written


func _write_locked(text: String, forced: bool) -> bool:
	"""`write` under the mutex: the cap, the file, the tail."""
	var size_bytes: int = text.to_utf8_buffer().size() + 1
	var limit: int = MAX_BYTES + (RESERVE_BYTES if forced else 0)
	if _bytes + size_bytes > limit:
		_dropped += 1
		if not _capped and _bytes + 200 <= MAX_BYTES + RESERVE_BYTES:
			_capped = true
			_store(CAPPED_LINE % MAX_KIB)
		return false
	_store(text)
	return true


func _store(text: String) -> void:
	"""Append and flush one line, and keep it in the tail."""
	_tail[_tail_next] = text
	_tail_next = (_tail_next + 1) % TAIL_LINES
	_tail_count = mini(_tail_count + 1, TAIL_LINES)
	if _file == null:
		return
	_file.store_line(text)
	_file.flush()
	_bytes += text.to_utf8_buffer().size() + 1


func note_repeat(key: String) -> bool:
	"""Count one occurrence of `key` (an error's kind and text); true while it should still be written."""
	_mutex.lock()
	var seen: int = int(_repeats.get(key, 0)) + 1
	if _repeats.size() < MAX_REPEAT_KEYS or _repeats.has(key):
		_repeats[key] = seen
	var keep: bool = seen <= REPEAT_LIMIT
	if not keep:
		_suppressed += 1
	_mutex.unlock()
	return keep


func suppressed() -> int:
	"""Repeated lines counted but not written."""
	return _suppressed


func dropped() -> int:
	"""Lines dropped at the cap."""
	return _dropped


func bytes() -> int:
	"""Bytes written so far."""
	return _bytes


func tail(most: int) -> PackedStringArray:
	"""The newest `most` lines written (at most TAIL_LINES), oldest first."""
	_mutex.lock()
	var count: int = mini(most, _tail_count)
	var out := PackedStringArray()
	for k: int in range(count, 0, -1):
		out.append(_tail[(_tail_next - k + TAIL_LINES) % TAIL_LINES])
	_mutex.unlock()
	return out


func close() -> void:
	"""Flush and close the file (later writes only reach the tail)."""
	_mutex.lock()
	if _file != null:
		_file.flush()
		_file.close()
		_file = null
	_mutex.unlock()
