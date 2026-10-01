extends Node3D
## A soft hummed phrase where a song is sung: the songs' only sound. Decision 0442 (the audio choice). Presentation
## only.
##
## NO NEW FILES. No voiced recording is staged (the demo's CC0 library holds none), and no download is made: each
## song's `tune` (song_book.gd: semitones over BASE_HZ, in eighths) is SYNTHESISED once, the first time it is wanted,
## into an AudioStreamWAV in memory -- a closed-mouth hum: a sine with two quiet overtones, a slow vibrato, each note
## eased in and out. It is never words: the words are the bubbles'.
## SUBTLE AND ON ITS OWN BUS. Every phrase plays on the SONGS bus (sound_mix.gd BUS_SONGS: its own volume and Mute in
## the game menu's Settings), positional at the singer, VOLUME_DB under the bus and gone by RANGE_M. At most VOICES
## phrases sound at once; a busy pool skips the phrase. The diegetic hum is not the score: the demo has no score, and
## nothing here would play one.

const BookScript := preload("res://demo/songs/song_book.gd")
const SoundMix := preload("res://demo/sound/sound_mix.gd")

const MIX_RATE: int = 22050
const BASE_HZ: float = 196.0
const EIGHTH_S: float = 0.19
const ATTACK_S: float = 0.05
const RELEASE_S: float = 0.09
const VIBRATO_HZ: float = 5.0
const VIBRATO_DEPTH: float = 0.004
const OVERTONES: PackedFloat32Array = [1.0, 0.28, 0.1]
const AMPLITUDE: float = 0.3
const VOICES: int = 3
const VOLUME_DB: float = -14.0
const RANGE_M: float = 18.0
const UNIT_SIZE_M: float = 4.0

var _book: BookScript = null
var _streams: Array[AudioStreamWAV] = []
var _players: Array[AudioStreamPlayer3D] = []


func configure(book: BookScript) -> void:
	"""Hum `book`'s tunes; the players are made once, here."""
	name = "SongHum"
	_book = book
	_streams.resize(book.size())
	for k: int in VOICES:
		var player := AudioStreamPlayer3D.new()
		player.bus = SoundMix.BUS_NAMES[SoundMix.BUS_SONGS]
		player.volume_db = VOLUME_DB
		player.max_distance = RANGE_M
		player.unit_size = UNIT_SIZE_M
		player.attenuation_filter_cutoff_hz = 20500.0
		add_child(player)
		_players.append(player)


func hum(song: int, at: Vector3) -> bool:
	"""Hum song `song`'s phrase at `at` on a free voice; false when every voice is busy, there is no such song, or the
	hum is not in the tree (nothing can sound)."""
	if _book == null or song < 0 or song >= _book.size() or not is_inside_tree():
		return false
	for player: AudioStreamPlayer3D in _players:
		if player.playing:
			continue
		player.stream = stream_of(song)
		player.global_position = at
		player.play()
		return true
	return false


func stop_all() -> void:
	"""Silence every voice (songs switched off)."""
	for player: AudioStreamPlayer3D in _players:
		player.stop()


func warm() -> int:
	"""Make every song's phrase now (the boot prewarm, demo_prewarm.gd's `step() -> int`: about 10 ms a song, better
	behind the opening pause than at a first verse). Returns how many phrases there are."""
	for song: int in _streams.size():
		stream_of(song)
	return _streams.size()


func stream_of(song: int) -> AudioStreamWAV:
	"""Song `song`'s hummed phrase, made the first time it is wanted."""
	if _streams[song] == null:
		_streams[song] = synthesise(_book.tunes[song], _book.beats[song])
	return _streams[song]


static func synthesise(tune: PackedInt32Array, beats: PackedInt32Array) -> AudioStreamWAV:
	"""A hummed phrase (see NO NEW FILES): 16-bit mono at MIX_RATE, each note `beats` eighths long."""
	var total: int = 0
	for beat: int in beats:
		total += int(float(beat) * EIGHTH_S * float(MIX_RATE))
	var data := PackedByteArray()
	data.resize(total * 2)
	var at: int = 0
	var phase: float = 0.0
	for k: int in tune.size():
		var length: int = int(float(beats[k]) * EIGHTH_S * float(MIX_RATE))
		var hz: float = BASE_HZ * pow(2.0, float(tune[k]) / 12.0)
		phase = _note_into(data, at, length, hz, phase)
		at += length
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = data
	return wav


static func _note_into(data: PackedByteArray, start: int, length: int, hz: float, phase: float) -> float:
	"""One note's samples into `data` from sample `start`; returns the running phase (no click between notes)."""
	var step: float = TAU * hz / float(MIX_RATE)
	for n: int in length:
		var t: float = float(n) / float(MIX_RATE)
		var left: float = float(length - n) / float(MIX_RATE)
		var envelope: float = minf(1.0, minf(t / ATTACK_S, left / RELEASE_S))
		phase += step * (1.0 + VIBRATO_DEPTH * sin(TAU * VIBRATO_HZ * t))
		var value: float = 0.0
		for h: int in OVERTONES.size():
			value += OVERTONES[h] * sin(phase * float(h + 1))
		var sample: int = clampi(int(value * AMPLITUDE * envelope * 32767.0 / 1.38), -32768, 32767)
		data.encode_s16((start + n) * 2, sample)
	return fmod(phase, TAU)


func voice(k: int) -> AudioStreamPlayer3D:
	"""Voice `k` (checks)."""
	return _players[k]
