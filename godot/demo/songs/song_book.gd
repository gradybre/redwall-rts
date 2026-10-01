extends RefCounted
## The village repertoire, read from songs.json: each song's id, title, context, lines and tune. Decision 0442.
## Presentation only.
##
## THE DATA (songs.json). Every song is ORIGINAL to this demo (decision 0442's originality rule: no line, name or
## phrase from any book). A song has a unique `id`, a `title`, one `context` -- "work" (sung only while actually
## working: hauling, carrying, at a task), "supper" (seated at the supper table) or "evening" (the quiet hour between
## supper and bed) -- 4 to 8 `lines`, and a `tune` (semitones over the hum's base note) with its `beats` (eighths),
## which song_hum.gd turns into a hummed phrase. A line may carry ONE `{deed}` slot: it is filled with a deed the
## village has recorded (a bridge it opened, a swimmer it brought ashore; demo_songs.gd `deeds`) or else the song's
## `deed_fallback` -- never invented history.
## THE LIMIT. A bubble shows one line at a time, so no line may be longer than `line_limit` characters with its
## slot filled by a deed of `deed_limit` characters; `load_from` refuses a book that breaks it, or any other rule
## above, and says which song and line.

const DEFAULT_PATH: String = "res://demo/songs/songs.json"
const CONTEXT_NONE: int = 0
const CONTEXT_WORK: int = 1
const CONTEXT_SUPPER: int = 2
const CONTEXT_EVENING: int = 3
const CONTEXT_KEYS: Array[String] = ["", "work", "supper", "evening"]
const CONTEXT_COUNT: int = 4
const MIN_LINES: int = 4
const MAX_LINES: int = 8
const SLOT: String = "{deed}"
## The most songs a book may hold (a resident's learned songs are one bit each in a 32-bit mask).
const MAX_SONGS: int = 16

var ids: Array[StringName] = []
var titles: PackedStringArray = PackedStringArray()
var contexts: PackedInt32Array = PackedInt32Array()
var lines: Array[PackedStringArray] = []
var tunes: Array[PackedInt32Array] = []
var beats: Array[PackedInt32Array] = []
var fallbacks: PackedStringArray = PackedStringArray()
var line_limit: int = 44
var deed_limit: int = 20
## Why the last load refused ("" when it took).
var error: String = ""


func size() -> int:
	"""How many songs the book holds."""
	return ids.size()


func load_from(path: String = DEFAULT_PATH) -> bool:
	"""Read the book at `path`; on any broken rule (see THE DATA and THE LIMIT) keep nothing and say why in `error`."""
	var text: String = FileAccess.get_file_as_string(path)
	var data: Variant = JSON.parse_string(text)
	if not data is Dictionary:
		return _fail("%s is not a JSON object" % path)
	return load_data(data as Dictionary)


func load_data(data: Dictionary) -> bool:
	"""Take the book from parsed data (see load_from)."""
	_clear()
	line_limit = int(data.get("line_limit", 0))
	deed_limit = int(data.get("deed_limit", 0))
	if line_limit <= 0 or deed_limit < 0:
		return _fail("line_limit and deed_limit must be set")
	var songs: Array = data.get("songs", []) as Array
	if songs.is_empty() or songs.size() > MAX_SONGS:
		return _fail("a book holds 1 to %d songs" % MAX_SONGS)
	for spec: Variant in songs:
		if not spec is Dictionary or not _take(spec as Dictionary):
			var keep: String = error if not error.is_empty() else "a song is not an object"
			_clear()
			return _fail(keep)
	return true


func _take(spec: Dictionary) -> bool:
	"""One song, checked; false (with `error`) when it breaks a rule."""
	var id := StringName(str(spec.get("id", "")))
	if id == &"" or ids.has(id):
		return _fail("song id '%s' is empty or repeated" % id)
	var context: int = CONTEXT_KEYS.find(str(spec.get("context", "")))
	if context <= CONTEXT_NONE:
		return _fail("%s: unknown context" % id)
	var words := PackedStringArray(spec.get("lines", []) as Array)
	if words.size() < MIN_LINES or words.size() > MAX_LINES:
		return _fail("%s: %d lines (a song has %d to %d)" % [id, words.size(), MIN_LINES, MAX_LINES])
	var fallback: String = str(spec.get("deed_fallback", ""))
	for k: int in words.size():
		var why: String = _line_problem(words[k], fallback)
		if not why.is_empty():
			return _fail("%s line %d: %s" % [id, k + 1, why])
	var tune := PackedInt32Array(spec.get("tune", []) as Array)
	var beat := PackedInt32Array(spec.get("beats", []) as Array)
	if tune.is_empty() or tune.size() != beat.size():
		return _fail("%s: tune and beats must be the same, non-empty length" % id)
	ids.append(id)
	titles.append(str(spec.get("title", id)))
	contexts.append(context)
	lines.append(words)
	tunes.append(tune)
	beats.append(beat)
	fallbacks.append(fallback)
	return true


func _line_problem(line: String, fallback: String) -> String:
	"""What is wrong with one line ("" when nothing): empty, more than one slot, a slot with no fallback, or too long
	with its slot filled by the longest deed."""
	if line.strip_edges().is_empty():
		return "empty"
	var slots: int = line.count(SLOT)
	if slots > 1:
		return "more than one slot"
	if slots == 1 and (fallback.is_empty() or fallback.length() > deed_limit):
		return "a slot needs a deed_fallback of at most deed_limit characters"
	var longest: int = line.length() + (deed_limit - SLOT.length() if slots == 1 else 0)
	if longest > line_limit:
		return "%d characters with the slot filled (limit %d)" % [longest, line_limit]
	return ""


func _fail(why: String) -> bool:
	"""Refuse, saying why."""
	error = why
	return false


func _clear() -> void:
	"""Keep nothing."""
	error = ""
	ids.clear()
	titles.clear()
	contexts.clear()
	lines.clear()
	tunes.clear()
	beats.clear()
	fallbacks.clear()


func line_count(song: int) -> int:
	"""How many lines song `song` has."""
	return lines[song].size()


func line_text(song: int, k: int, deed: String = "") -> String:
	"""Line `k` of song `song`, its slot filled with `deed` -- or the song's fallback when `deed` is empty or longer
	than deed_limit."""
	var line: String = lines[song][k]
	if not line.contains(SLOT):
		return line
	var fill: String = deed if not deed.is_empty() and deed.length() <= deed_limit else fallbacks[song]
	return line.replace(SLOT, fill)


func songs_for(context: int, out: PackedInt32Array) -> int:
	"""The songs of `context` into `out` (cleared first), in book order. Returns how many."""
	out.clear()
	for song: int in ids.size():
		if contexts[song] == context:
			out.append(song)
	return out.size()


func all_mask() -> int:
	"""Every song's bit (what an otter knows from the start)."""
	return (1 << ids.size()) - 1
