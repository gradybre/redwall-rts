extends RefCounted
## The live demo's sound table: every cue the demo can play, read from data at boot (sound_table.json),
## so sound files drop in later with no code change. Decision 0351 (review F43, UX-029, UX-031). Presentation
## only: nothing here, or anywhere in demo/sound/, writes to the simulation or to any demo model.
##
## A CUE is a row of packed columns: its id, its bus (SoundMix.BUS_*), whether it is placed in the world
## (`positional`, heard from the listener over `range_m`) or flat, whether it loops, its volume, the least
## REAL time between two plays (`gap_ms`: the same at 1x and 4x, so a faster clock never stacks a cue), how
## many may sound at once (`voices`), its files (variants, played in turn) and its EQUIVALENT: what shows the
## player the same thing with the sound off (UX-031, UI §7 "All sound cues have visible text"). A row with
## no equivalent is refused, so a cue cannot be the only way to learn something.
##
## MISSING FILES. The files are not in git: tools/stage_demo_audio.py stages them from the gitignored CC0 audio
## library (decision 0351, phase 2), and a checkout without them (CI) has none, so every cue plays SILENT there:
## `load_streams` loads what exists, and warns ONCE per cue whose files are missing. A silent cue still
## takes its voice and its gap (sound_voices.gd), so the caps and the event map behave as they will with audio.

const SoundMix := preload("res://demo/sound/sound_mix.gd")

const DEFAULT_PATH: String = "res://demo/sound/sound_table.json"
## Bus keys as the JSON names them, by SoundMix.BUS_* (Master is no cue's bus).
const BUS_KEYS: Array[String] = ["", "ambience", "work", "water", "cues", "songs"]
const MIN_VOLUME_DB: float = -60.0
const MAX_VOLUME_DB: float = 6.0
const MAX_VOICES: int = 8
const MAX_FILES: int = 8

var ids: Array[StringName] = []
var bus: PackedInt32Array = PackedInt32Array()
var positional: PackedByteArray = PackedByteArray()
var loop: PackedByteArray = PackedByteArray()
var volume_db: PackedFloat32Array = PackedFloat32Array()
var range_m: PackedFloat32Array = PackedFloat32Array()
var gap_ms: PackedInt32Array = PackedInt32Array()
var voices: PackedInt32Array = PackedInt32Array()
var equivalent: PackedStringArray = PackedStringArray()
var files: Array[PackedStringArray] = []
## Per cue: the streams loaded (`load_streams`); empty -- the cue plays silent.
var streams: Array[Array] = []
## Per cue: whether its missing files were warned about (once).
var warned: PackedByteArray = PackedByteArray()
## How many missing-file warnings were given (at most one per cue, ever).
var warnings: int = 0
## What the last load refused, one line per problem.
var errors: PackedStringArray = PackedStringArray()

var _row_of: Dictionary = {}


func count() -> int:
	"""How many cues the table holds."""
	return ids.size()


func row(id: StringName) -> int:
	"""Cue `id`'s row (-1: no such cue)."""
	return int(_row_of.get(id, -1))


func load_from(path: String = DEFAULT_PATH) -> bool:
	"""Read the table at `path`. False (and `errors` says why) when it is missing or not a table; rows that
	fail their checks are left out and listed in `errors`."""
	if not FileAccess.file_exists(path):
		errors.append("no sound table at %s" % path)
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		errors.append("the sound table at %s is not a JSON object" % path)
		return false
	return parse(parsed as Dictionary)


func parse(data: Dictionary) -> bool:
	"""Take every cue of `data["cues"]` that passes its checks. True when at least one did and none failed."""
	var cues: Variant = data.get("cues")
	if typeof(cues) != TYPE_DICTIONARY:
		errors.append("the sound table has no \"cues\" object")
		return false
	var all_ok: bool = true
	for key: Variant in (cues as Dictionary).keys():
		var spec: Variant = (cues as Dictionary)[key]
		if typeof(spec) != TYPE_DICTIONARY or not add(StringName(str(key)), spec as Dictionary):
			all_ok = false
	return all_ok and count() > 0


func add(id: StringName, spec: Dictionary) -> bool:
	"""Add cue `id` from its spec (the JSON row's fields), or refuse it (false, with the reason in `errors`)."""
	var refusal: String = refusal_of(id, spec)
	if not refusal.is_empty():
		errors.append("sound cue %s: %s" % [id, refusal])
		return false
	_row_of[id] = ids.size()
	ids.append(id)
	bus.append(BUS_KEYS.find(str(spec["bus"])))
	positional.append(1 if bool(spec.get("positional", false)) else 0)
	loop.append(1 if bool(spec.get("loop", false)) else 0)
	volume_db.append(float(spec.get("volume_db", 0.0)))
	range_m.append(float(spec.get("range_m", 0.0)))
	gap_ms.append(int(spec.get("gap_ms", 0)))
	voices.append(int(spec.get("voices", 1)))
	equivalent.append(str(spec["equivalent"]))
	files.append(PackedStringArray(spec.get("files", []) as Array))
	streams.append([])
	warned.append(0)
	return true


func refusal_of(id: StringName, spec: Dictionary) -> String:
	"""Why a cue spec cannot be taken ("" when it can)."""
	if _row_of.has(id):
		return "listed twice"
	if BUS_KEYS.find(str(spec.get("bus", ""))) < 1:
		return "bus must be one of ambience, work, water, cues"
	if str(spec.get("equivalent", "")).strip_edges().is_empty():
		return "no equivalent: every cue needs a text or picture match for muted play"
	var volume: float = float(spec.get("volume_db", 0.0))
	if volume < MIN_VOLUME_DB or volume > MAX_VOLUME_DB:
		return "volume_db outside %d..%d" % [int(MIN_VOLUME_DB), int(MAX_VOLUME_DB)]
	if bool(spec.get("positional", false)) and float(spec.get("range_m", 0.0)) <= 0.0:
		return "a positional cue needs a range_m above 0"
	if int(spec.get("gap_ms", 0)) < 0 or int(spec.get("voices", 1)) < 1 or int(spec.get("voices", 1)) > MAX_VOICES:
		return "gap_ms below 0 or voices outside 1..%d" % MAX_VOICES
	if typeof(spec.get("files", [])) != TYPE_ARRAY or (spec.get("files", []) as Array).size() > MAX_FILES:
		return "files must be a list of at most %d paths" % MAX_FILES
	return ""


func load_streams() -> int:
	"""Load every cue's files that exist (the boot prewarm's step, so no first play loads mid-game); warn once
	per cue with files missing. Returns how many streams were loaded."""
	var loaded: int = 0
	for r: int in count():
		loaded += _load_row(r)
	return loaded


func _load_row(r: int) -> int:
	"""Load cue `r`'s files that exist, as AudioStreams (looping ones set to loop); warn once if any is missing."""
	var found: Array = []
	var missing: PackedStringArray = PackedStringArray()
	for path: String in files[r]:
		var stream := load(path) as AudioStream if ResourceLoader.exists(path) else null
		if stream == null:
			missing.append(path)
			continue
		_set_looping(stream, loop[r] == 1)
		found.append(stream)
	streams[r] = found
	if (not missing.is_empty() or files[r].is_empty()) and warned[r] == 0:
		warned[r] = 1
		warnings += 1
		push_warning("sound cue %s: %d of %d files missing (%s); it plays silent until they are staged" % [ids[r],
			missing.size(), files[r].size(), ", ".join(missing)])
	return found.size()


static func _set_looping(stream: AudioStream, looping: bool) -> void:
	"""Loop an Ogg or MP3 stream as its cue says (a WAV keeps the loop authored in the file)."""
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = looping
	elif stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = looping


func stream_of(r: int, variant: int) -> AudioStream:
	"""Cue `r`'s variant `variant` (taken round its loaded streams), or null: silent."""
	var loaded: Array = streams[r]
	if loaded.is_empty():
		return null
	return loaded[posmod(variant, loaded.size())] as AudioStream


func is_silent(r: int) -> bool:
	"""Whether cue `r` has no stream loaded."""
	return (streams[r] as Array).is_empty()
