extends Node3D
## The demo's one-shot voices: a bounded pool of players made once, per bus, and the rules that keep many
## workers and a 4x clock from stacking sound. Decision 0351 (review F43, UX-029, UX-031). Presentation only.
##
## THE POOL. POOL_SIZES players per bus, made in `build` and never again: AudioStreamPlayer3D for the world's
## buses (Work, Water), placed where the cue happened; AudioStreamPlayer for Cues (flat). Ambience has none:
## its loops are the director's (sound_director.gd).
##
## A PLAY (`play`) is refused, with nothing changed but a counter, when:
##   * GAP     the cue played less than its `gap_ms` of REAL time ago (Time's milliseconds, never the demo
##             clock: at 4x the demo raises events four times as often and the gap folds them into the same
##             plays per second as at 1x -- AGGREGATION; `folded` counts them);
##   * CUE CAP the cue already sounds on its `voices` players;
##   * BUS CAP every player of its bus is busy.
## A voice is BUSY until its stream's length has run -- or, for a silent cue (no file staged), HOLD_MS -- so
## the caps behave the same with and without files. No player's pitch is ever changed: 4x does not pitch up.

const SoundTable := preload("res://demo/sound/sound_table.gd")
const SoundMix := preload("res://demo/sound/sound_mix.gd")

const PLAYED: int = 0
const REFUSE_GAP: int = 1
const REFUSE_CUE_CAP: int = 2
const REFUSE_BUS_CAP: int = 3
const REFUSE_NO_POOL: int = 4
## Players per bus (SoundMix.BUS_* order): none for Master and Ambience, none for Songs (demo/songs/song_hum.gd has
## its own voices).
const POOL_SIZES: PackedInt32Array = [0, 0, 8, 4, 3, 0]
## A silent cue holds its voice this long (ms): about a footstep's or a chop's sound.
const HOLD_MS: int = 350
## A positional voice is at full volume within this share of its cue's range.
const UNIT_SHARE: float = 0.3

var _table: SoundTable = null
## Per voice: its player -- placed (Work, Water) or flat (Cues); the other column holds null.
var _placed: Array[AudioStreamPlayer3D] = []
var _flat: Array[AudioStreamPlayer] = []
var _player_bus: PackedInt32Array = PackedInt32Array()
## Per voice: the cue it sounds (-1: none) and until when (Time msec).
var _voice_cue: PackedInt32Array = PackedInt32Array()
var _voice_until: PackedInt64Array = PackedInt64Array()
## Per cue: when it last played (Time msec; a large negative: never), offers (every `play` call), plays, folds,
## and the next variant.
var _last_play: PackedInt64Array = PackedInt64Array()
var offered: PackedInt32Array = PackedInt32Array()
var played: PackedInt32Array = PackedInt32Array()
var folded: PackedInt32Array = PackedInt32Array()
var _variant: PackedInt32Array = PackedInt32Array()
## Refusals by REFUSE_* (checks and the cost report).
var refused: PackedInt32Array = PackedInt32Array([0, 0, 0, 0, 0])


func _init() -> void:
	"""Named."""
	name = "SoundVoices"


func build(table: SoundTable) -> void:
	"""Make every bus's players (once) and size the per-cue columns to `table`."""
	_table = table
	if _player_bus.is_empty():
		for bus: int in POOL_SIZES.size():
			for k: int in POOL_SIZES[bus]:
				_add_player(bus)
	var cues: int = table.count()
	_last_play.resize(cues)
	_last_play.fill(-1000000)
	for column: PackedInt32Array in [offered, played, folded, _variant]:
		column.resize(cues)
		column.fill(0)


func _add_player(bus: int) -> void:
	"""One idle player of bus `bus`: placed in the world for Work and Water, flat for Cues."""
	var flat: AudioStreamPlayer = AudioStreamPlayer.new() if bus == SoundMix.BUS_CUES else null
	var placed: AudioStreamPlayer3D = AudioStreamPlayer3D.new() if flat == null else null
	var player: Node = (flat as Node) if flat != null else (placed as Node)
	player.name = "Voice%d" % _player_bus.size()
	add_child(player)
	_flat.append(flat)
	_placed.append(placed)
	_player_bus.append(bus)
	_voice_cue.append(-1)
	_voice_until.append(0)


func voice_count() -> int:
	"""How many players the pool holds."""
	return _player_bus.size()


func play(row: int, at: Vector3, below: bool, now_msec: int) -> int:
	"""Sound cue `row` at `at` (a flat cue ignores it), on the Work bus's underground half when `below`.
	Returns PLAYED or why not (REFUSE_*; see A PLAY)."""
	offered[row] += 1
	var code: int = admit(row, now_msec)
	if code != PLAYED:
		refused[code] += 1
		if code == REFUSE_GAP:
			folded[row] += 1
		return code
	var voice: int = _free_voice(_table.bus[row], now_msec)
	_last_play[row] = now_msec
	played[row] += 1
	_start(voice, row, at, below, now_msec)
	return PLAYED


func admit(row: int, now_msec: int) -> int:
	"""Whether cue `row` may play now: PLAYED, or the REFUSE_* that stops it."""
	var bus: int = _table.bus[row]
	if bus < 0 or bus >= POOL_SIZES.size() or POOL_SIZES[bus] == 0:
		return REFUSE_NO_POOL
	if now_msec - _last_play[row] < _table.gap_ms[row]:
		return REFUSE_GAP
	if sounding(row, now_msec) >= _table.voices[row]:
		return REFUSE_CUE_CAP
	if _free_voice(bus, now_msec) < 0:
		return REFUSE_BUS_CAP
	return PLAYED


func _free_voice(bus: int, now_msec: int) -> int:
	"""The first idle player of `bus` (-1: all busy)."""
	for voice: int in _player_bus.size():
		if _player_bus[voice] == bus and _voice_until[voice] <= now_msec:
			return voice
	return -1


func _start(voice: int, row: int, at: Vector3, below: bool, now_msec: int) -> void:
	"""Hand voice `voice` cue `row`'s next variant, busy for its length (HOLD_MS when silent)."""
	var stream: AudioStream = _table.stream_of(row, _variant[row])
	_variant[row] += 1
	_voice_cue[voice] = row
	var length_ms: int = int(stream.get_length() * 1000.0) if stream != null else 0
	_voice_until[voice] = now_msec + (length_ms if length_ms > 0 else HOLD_MS)
	var bus_name: StringName = SoundMix.sub_bus_name(_table.bus[row], below)
	var placed: AudioStreamPlayer3D = _placed[voice]
	if placed == null:
		_go_flat(_flat[voice], stream, bus_name, _table.volume_db[row])
		return
	placed.position = at
	placed.max_distance = _table.range_m[row]
	placed.unit_size = maxf(_table.range_m[row] * UNIT_SHARE, 0.1)
	placed.bus = bus_name
	placed.volume_db = _table.volume_db[row]
	placed.stream = stream
	if stream != null and placed.is_inside_tree():
		placed.play()


static func _go_flat(player: AudioStreamPlayer, stream: AudioStream, bus_name: StringName, volume: float) -> void:
	"""Start a flat player (a silent cue only holds its voice: there is nothing to play)."""
	player.bus = bus_name
	player.volume_db = volume
	player.stream = stream
	if stream != null and player.is_inside_tree():
		player.play()


func sounding(row: int, now_msec: int) -> int:
	"""How many voices sound cue `row` now."""
	var n: int = 0
	for voice: int in _player_bus.size():
		if _voice_cue[voice] == row and _voice_until[voice] > now_msec:
			n += 1
	return n


func busy(bus: int, now_msec: int) -> int:
	"""How many of bus `bus`'s voices are busy now."""
	var n: int = 0
	for voice: int in _player_bus.size():
		if _player_bus[voice] == bus and _voice_until[voice] > now_msec:
			n += 1
	return n


func stop_bus(bus: int, now_msec: int) -> int:
	"""Stop every voice of bus `bus` now (the clock paused: work stops). Returns how many were still busy."""
	var stopped: int = 0
	for voice: int in _player_bus.size():
		if _player_bus[voice] != bus or _voice_cue[voice] < 0:
			continue
		var was_busy: bool = _voice_until[voice] > now_msec
		_voice_cue[voice] = -1
		_voice_until[voice] = 0
		if _placed[voice] != null:
			_placed[voice].stop()
		else:
			_flat[voice].stop()
		stopped += 1 if was_busy else 0
	return stopped


func silence() -> int:
	"""Stop every voice now, whatever its bus (the owner leaving the tree: sound_director.gd `_exit_tree`), so no
	playback outlives its player. Returns how many players were still playing."""
	var stopped: int = 0
	for voice: int in _player_bus.size():
		_voice_cue[voice] = -1
		_voice_until[voice] = 0
		var player: Node = (_placed[voice] as Node) if _placed[voice] != null else (_flat[voice] as Node)
		if bool(player.get(&"playing")):
			stopped += 1
		player.call(&"stop")
	return stopped


func pitch_of(voice: int) -> float:
	"""Voice `voice`'s pitch scale (checks: always 1.0)."""
	return _placed[voice].pitch_scale if _placed[voice] != null else _flat[voice].pitch_scale


func placed_player(voice: int) -> AudioStreamPlayer3D:
	"""Voice `voice`'s placed player (null for a flat one; checks)."""
	return _placed[voice]


func total_played() -> int:
	"""Plays across every cue (the cost report)."""
	var n: int = 0
	for count: int in played:
		n += count
	return n
