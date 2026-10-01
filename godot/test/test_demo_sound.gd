extends "res://test/framework/test_case.gd"
## The live demo's first sound pass (decision 0351; review F43, P8, UX-029, UX-031), with no sound files
## staged: the data table and its silent placeholders, the buses and their routing, the bounded voice pool
## (caps, real-time gaps, no stacking and no pitch-up at 4x), the pause duck and the underground filter, the
## Settings page's volumes, mutes and mixes, and the EVENT MAP sounding completed events only.
##
## Off-tree unless a test says otherwise; times are explicit milliseconds, so nothing waits on a clock. The
## buses are the real AudioServer's (made by name, idempotent), so each test puts the mix back.

const SoundTable := preload("res://demo/sound/sound_table.gd")
const SoundMix := preload("res://demo/sound/sound_mix.gd")
const VoicesScript := preload("res://demo/sound/sound_voices.gd")
const TapsScript := preload("res://demo/sound/sound_taps.gd")
const DirectorScript := preload("res://demo/sound/sound_director.gd")
const SettingsScript := preload("res://demo/sound/sound_settings_ui.gd")
const MenuScript := preload("res://demo/ui/demo_menu.gd")
const PrewarmScript := preload("res://demo/demo_prewarm.gd")
const BrainScript := preload("res://demo/cast/resident_brain.gd")
const SwimStateScript := preload("res://demo/waterplay/swim_state.gd")
const JobsScript := preload("res://demo/forestry/forest_jobs.gd")
const StandScript := preload("res://demo/forestry/forest_stand.gd")
const BridgesScript := preload("res://demo/waterplay/bridges.gd")
const NoticesScript := preload("res://demo/demo_notices.gd")
const WeatherScript := preload("res://demo/weather/demo_weather.gd")
const WaterLayout := preload("res://demo/water/water_layout.gd")
const GraphScript := preload("res://demo/tunnel/underground_graph.gd")
const GroundScript := preload("res://demo/tunnel/tunnel_ground.gd")
const Rules := preload("res://demo/tunnel/tunnel_rules.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const SkillsScript := preload("res://demo/forestry/forest_skills.gd")
const GameManagerScript := preload("res://scripts/systems/game_manager.gd")
const WorldLayout := preload("res://demo/world/world_layout.gd")

const WOOD: int = 60
## Frames of 1/60 s for the real-time runs.
const FRAME_MS: int = 16

var _nodes: Array[Node] = []
var _read: IntMath.IntResult = IntMath.IntResult.new()


func after_each() -> void:
	"""Free what a test built; the mix back to Balanced, unpaused, above ground."""
	for node: Node in _nodes:
		if is_instance_valid(node):
			node.free()
	_nodes.clear()
	SoundMix.reset()
	var mix := SoundMix.new()
	mix.ensure_buses()
	mix.apply()


func _director() -> DirectorScript:
	"""A director over the shipped table, off-tree."""
	var director := DirectorScript.new()
	_nodes.append(director)
	assert_true(director.configure(), "the shipped table reads")
	return director


func _shipped() -> SoundTable:
	"""The shipped table."""
	var table := SoundTable.new()
	assert_true(table.load_from(), "the shipped table reads")
	return table


func _cue(bus: String, gap_ms: int, voices: int) -> Dictionary:
	"""A cue spec for the cap tests: placed for the world's buses, no files."""
	return {"bus": bus, "positional": bus != "cues", "range_m": 30.0, "volume_db": 0.0, "gap_ms": gap_ms,
		"voices": voices, "files": [], "equivalent": "seen"}


func _voices_over(cues: Dictionary) -> VoicesScript:
	"""A voice pool over a table of `cues`."""
	var table := SoundTable.new()
	assert_true(table.parse({"cues": cues}), "the test table reads")
	var voices := VoicesScript.new()
	_nodes.append(voices)
	voices.build(table)
	return voices


func _bus_db(bus_name: StringName) -> float:
	"""An AudioServer bus's volume now."""
	return AudioServer.get_bus_volume_db(AudioServer.get_bus_index(bus_name))


# --- the table and its silent placeholders -----------------------------------------------------------

func test_the_shipped_table_has_every_cue_on_a_bus_with_an_equivalent() -> void:
	"""Every cue the event map and the loops use is in the table, on a known bus, with a text or picture match."""
	var table := _shipped()
	assert_true(table.errors.is_empty(), "no refusals: %s" % ", ".join(table.errors))
	for id: StringName in TapsScript.CUE_IDS + DirectorScript.LOOP_IDS + [&"ui_click"]:
		var r: int = table.row(id)
		assert_true(r >= 0, "%s is in the table" % id)
		if r >= 0:
			assert_true(table.bus[r] >= SoundMix.BUS_AMBIENCE and table.bus[r] < SoundMix.BUS_COUNT, "%s has a bus" % id)
			assert_false(table.equivalent[r].strip_edges().is_empty(), "%s has an equivalent" % id)


func test_a_cue_without_an_equivalent_or_with_an_unknown_bus_is_refused() -> void:
	"""A cue a muted player could miss, or one on no bus, is not taken; the rest are."""
	var table := SoundTable.new()
	var cues := {"ok": _cue("work", 0, 1), "mute_only": _cue("work", 0, 1), "nowhere": _cue("hall", 0, 1)}
	(cues["mute_only"] as Dictionary)["equivalent"] = " "
	assert_false(table.parse({"cues": cues}), "not every cue was taken")
	assert_equal(table.count(), 1, "only the good cue")
	assert_true(table.row(&"ok") >= 0, "the good cue")
	assert_equal(table.errors.size(), 2, "two refusals said")
	assert_false(SoundTable.new().load_from("res://demo/sound/no_such_table.json"), "a missing table refuses")


func test_each_bad_field_refuses_its_cue() -> void:
	"""A loud volume, a placed cue with no range, a negative gap, no voices or too many, files that are not a
	list or too many, and a second cue of the same id: each is refused, saying which."""
	var bad: Array[Dictionary] = []
	for field: Array in [["volume_db", 12.0], ["range_m", 0.0], ["gap_ms", -1], ["voices", 0], ["voices", 9],
			["files", "chop.ogg"], ["files", ["1", "2", "3", "4", "5", "6", "7", "8", "9"]]]:
		var spec: Dictionary = _cue("work", 0, 1)
		spec[field[0]] = field[1]
		bad.append(spec)
	for spec: Dictionary in bad:
		var table := SoundTable.new()
		assert_false(table.add(&"bad", spec), "refused: %s" % str(spec))
		assert_equal(table.count(), 0, "nothing taken")
	var twice := SoundTable.new()
	assert_true(twice.add(&"knock", _cue("work", 0, 1)), "the first")
	assert_false(twice.add(&"knock", _cue("work", 0, 1)), "the same id again")
	assert_true(twice.errors[0].contains("listed twice"), "says so")
	assert_true(SoundTable.new().add(&"flat", _cue("cues", 0, 1)), "a flat cue needs no range")


func test_missing_files_play_silent_with_one_warning_per_cue() -> void:
	"""Nothing staged: no stream loads, every cue is silent, each warned about once however often it loads."""
	var table := _shipped()
	assert_equal(table.load_streams(), 0, "nothing to load")
	assert_equal(table.warnings, table.count(), "one warning per cue")
	assert_equal(table.load_streams(), 0, "again")
	assert_equal(table.warnings, table.count(), "no second warning")
	for r: int in table.count():
		assert_true(table.is_silent(r), "%s is silent" % table.ids[r])
		assert_null(table.stream_of(r, 0), "%s has no stream" % table.ids[r])


func test_a_silent_cue_still_plays_its_voice_and_its_gap() -> void:
	"""With no file the director still gives a cue its voice and its gap, so caps behave as they will with audio."""
	var director := _director()
	director.warm()
	var chop: int = director.table.row(&"chop")
	assert_equal(director.cue(chop, Vector3.ZERO, false, 1000), VoicesScript.PLAYED, "played (silent)")
	assert_equal(director.voices.sounding(chop, 1000), 1, "its voice is taken")
	assert_equal(director.voices.sounding(chop, 1000 + VoicesScript.HOLD_MS), 0, "and freed after HOLD_MS")


func test_the_prewarm_loads_the_streams_at_boot() -> void:
	"""The director's warm() is a prewarm step: run with the rest, reported (0 loaded while nothing is staged)."""
	var director := _director()
	var prewarm := PrewarmScript.new()
	_nodes.append(prewarm)
	prewarm.add_step("sound streams", director.warm)
	assert_equal(prewarm.warm(), 0, "nothing staged")
	assert_equal(String(prewarm.report[0]["step"]), "sound streams", "reported")
	assert_true(director.is_silent(), "the director knows it is silent")


# --- buses and routing -------------------------------------------------------------------------------

func test_buses_are_made_once_and_route_to_master_and_work() -> void:
	"""Ambience, Work, Water and Cues send to Master; Work's two halves send to Work; making them twice adds none."""
	var mix := SoundMix.new()
	mix.ensure_buses()
	var before: int = AudioServer.bus_count
	mix.ensure_buses()
	assert_equal(AudioServer.bus_count, before, "no second set")
	for bus: int in range(1, SoundMix.BUS_COUNT):
		var index: int = AudioServer.get_bus_index(SoundMix.BUS_NAMES[bus])
		assert_true(index > 0, "%s exists" % SoundMix.BUS_NAMES[bus])
		assert_equal(AudioServer.get_bus_send(index), &"Master", "%s sends to Master" % SoundMix.BUS_NAMES[bus])
	for half: StringName in [SoundMix.WORK_SURFACE, SoundMix.WORK_UNDER]:
		assert_equal(AudioServer.get_bus_send(AudioServer.get_bus_index(half)), &"Work", "%s sends to Work" % half)


func test_each_cue_sounds_on_its_bus_and_work_below_goes_through_work_under() -> void:
	"""The table's bus decides the player's: chop on Work's surface half (or, below, its underground half),
	splash on Water, the warning flat on Cues."""
	var director := _director()
	var table: SoundTable = director.table
	assert_equal(table.bus[table.row(&"chop")], SoundMix.BUS_WORK, "chop: Work")
	assert_equal(table.bus[table.row(&"splash")], SoundMix.BUS_WATER, "splash: Water")
	assert_equal(table.bus[table.row(&"amb_rain")], SoundMix.BUS_AMBIENCE, "rain: Ambience")
	assert_equal(table.bus[table.row(&"warning")], SoundMix.BUS_CUES, "warning: Cues")
	assert_equal(SoundMix.sub_bus_name(SoundMix.BUS_WORK, false), SoundMix.WORK_SURFACE, "work above")
	assert_equal(SoundMix.sub_bus_name(SoundMix.BUS_WORK, true), SoundMix.WORK_UNDER, "work below")
	assert_equal(director.cue(table.row(&"dig"), Vector3.ZERO, true, 1000), VoicesScript.PLAYED, "a dig below")
	assert_equal(_placed_on(director.voices, SoundMix.WORK_UNDER), 1, "one placed voice through Work Under")
	assert_equal(director.cue(table.row(&"chop"), Vector3.ZERO, false, 1000), VoicesScript.PLAYED, "a chop above")
	assert_equal(_placed_on(director.voices, SoundMix.WORK_SURFACE), 1, "one through Work Surface")


func _placed_on(voices: VoicesScript, bus_name: StringName) -> int:
	"""How many placed voices were last given bus `bus_name`."""
	var n: int = 0
	for voice: int in voices.voice_count():
		if voices.placed_player(voice) != null and voices.placed_player(voice).bus == bus_name:
			n += 1
	return n


# --- the voice pool: gaps, caps, 4x ------------------------------------------------------------------

func test_the_gap_folds_a_cue_played_again_too_soon() -> void:
	"""Within its gap a cue is refused and counted as folded; at the gap it plays again."""
	var voices := _voices_over({"knock": _cue("work", 300, 4)})
	assert_equal(voices.play(0, Vector3.ZERO, false, 1000), VoicesScript.PLAYED, "first")
	assert_equal(voices.play(0, Vector3.ZERO, false, 1299), VoicesScript.REFUSE_GAP, "299 ms later: folded")
	assert_equal(voices.folded[0], 1, "counted")
	assert_equal(voices.play(0, Vector3.ZERO, false, 1300), VoicesScript.PLAYED, "300 ms later: plays")
	assert_equal(voices.played[0], 2, "two plays")


func test_a_cue_never_sounds_on_more_voices_than_its_cap() -> void:
	"""A cue capped at 2 takes no third voice while two still sound."""
	var voices := _voices_over({"knock": _cue("work", 0, 2)})
	assert_equal(voices.play(0, Vector3.ZERO, false, 1000), VoicesScript.PLAYED, "one")
	assert_equal(voices.play(0, Vector3.ZERO, false, 1001), VoicesScript.PLAYED, "two")
	assert_equal(voices.play(0, Vector3.ZERO, false, 1002), VoicesScript.REFUSE_CUE_CAP, "not three")
	assert_equal(voices.sounding(0, 1002), 2, "two sound")
	assert_equal(voices.play(0, Vector3.ZERO, false, 1000 + VoicesScript.HOLD_MS), VoicesScript.PLAYED, "one freed")


func test_a_full_bus_refuses_until_a_voice_frees() -> void:
	"""Water has 4 voices: a fifth water cue is refused while all four sound, whatever its own cap."""
	var cues := {}
	for k: int in 5:
		cues["drop%d" % k] = _cue("water", 0, 8)
	var voices := _voices_over(cues)
	for k: int in 4:
		assert_equal(voices.play(k, Vector3.ZERO, false, 1000), VoicesScript.PLAYED, "water voice %d" % k)
	assert_equal(voices.play(4, Vector3.ZERO, false, 1001), VoicesScript.REFUSE_BUS_CAP, "the bus is full")
	assert_equal(voices.busy(SoundMix.BUS_WATER, 1001), 4, "four busy")
	assert_equal(voices.play(4, Vector3.ZERO, false, 1000 + VoicesScript.HOLD_MS), VoicesScript.PLAYED, "freed")


func test_ambience_has_no_one_shot_voices() -> void:
	"""Ambience is loops only: a one-shot on it is refused (it would have no pool to stack in)."""
	var voices := _voices_over({"gust": _cue("ambience", 0, 1)})
	assert_equal(voices.play(0, Vector3.ZERO, false, 1000), VoicesScript.REFUSE_NO_POOL, "no pool")


func _fellers(n: int) -> Array:
	"""`n` residents felling at once: their brains and a job board with each one's fell under way."""
	var brains: Array[BrainScript] = []
	var jobs := JobsScript.new()
	for k: int in n:
		var brain := BrainScript.new()
		brain.position = Vector2(float(k % 5) * 0.8, float(k / 5) * 0.8)
		brains.append(brain)
		assert_true(jobs.open_into(JobsScript.KIND_FELL, k, 0, JobsScript.ORIGIN_PLAYER, _read), "fell %d" % k)
		jobs.assign(_read.value, k)
		jobs.step[_read.value] = 1
		jobs.issued[_read.value] = 1
	return [brains, jobs]


func _run_fellers(speed: int, seconds: int, n: int) -> Array:
	"""`n` fellers for `seconds` of real time at `speed`, through a director: [chop events raised, chops
	played, the most chop voices at once]."""
	var director := _director()
	var made: Array = _fellers(n)
	director.taps.brains = made[0]
	director.taps.jobs = made[1]
	director.taps.watch()
	var jobs: JobsScript = made[1]
	var chop: int = director.table.row(&"chop")
	var raised: int = 0
	var most: int = 0
	for frame: int in seconds * 1000 / FRAME_MS:
		var now: int = 1000 + frame * FRAME_MS
		for row: int in n:
			jobs.elapsed_usec[row] += FRAME_MS * 1000 * speed
		director.update(now, FRAME_MS / 1000.0)
		raised += director.taps.event_count
		most = maxi(most, director.voices.sounding(chop, now))
	return [raised, director.voices.played[chop], most]


func test_four_x_raises_more_strikes_but_never_stacks_them() -> void:
	"""Twenty fellers at 4x raise four times the strikes of 1x, but the chop plays no more often than its real-time
	gap allows and never on more than its voices: the faster clock and the crowd fold, they do not stack."""
	var one: Array = _run_fellers(1, 10, 20)
	var four: Array = _run_fellers(4, 10, 20)
	assert_true(int(four[0]) >= 3 * int(one[0]), "4x raises far more strikes (%d vs %d)" % [four[0], one[0]])
	var table := _shipped()
	var chop: int = table.row(&"chop")
	var allowed: int = 10000 / table.gap_ms[chop] + 1
	assert_true(int(four[1]) <= allowed, "4x plays at most the gap's %d (%d)" % [allowed, four[1]])
	assert_true(int(one[1]) <= allowed, "1x too (%d)" % one[1])
	assert_true(int(four[2]) <= table.voices[chop], "never more than %d chops at once" % table.voices[chop])


func _wav(ms: int) -> AudioStreamWAV:
	"""A silent 16-bit mono stream `ms` long (a real stream, so players really play)."""
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 22050
	var data := PackedByteArray()
	data.resize(22050 * 2 * ms / 1000)
	wav.data = data
	return wav


func _busy_player(director: DirectorScript) -> AudioStreamPlayer3D:
	"""The placed voice last given a stream (null: none)."""
	for voice: int in director.voices.voice_count():
		var player: AudioStreamPlayer3D = director.voices.placed_player(voice)
		if player != null and player.stream != null:
			return player
	return null


func test_a_chop_at_four_x_plays_at_pitch_one_its_range_and_its_variants() -> void:
	"""The clock at 4x and real streams: a felling beat raised through update() is given to a player at pitch 1,
	whose range is the cue's, for the stream's length; the next play takes the next variant. (That the player
	really plays, and that a pause really stops it, is the live harness's: the runner has no tree.)"""
	var director := _director()
	var clock := GameManagerScript.new()
	clock.start_game()
	assert_true(clock.set_speed(4), "4x")
	director.bind(null, clock, Callable())
	var chop: int = director.table.row(&"chop")
	var first: AudioStreamWAV = _wav(200)
	director.table.streams[chop] = [first, _wav(200)]
	var made: Array = _fellers(1)
	director.taps.brains = made[0]
	director.taps.jobs = made[1]
	director.taps.watch()
	(made[1] as JobsScript).elapsed_usec[0] = TapsScript.STRIKE_USEC
	director.update(5000, 0.016)
	assert_equal(director.voices.played[chop], 1, "the beat played through update() at 4x")
	for voice: int in director.voices.voice_count():
		assert_almost_equal(director.voices.pitch_of(voice), 1.0, "voice %d at pitch 1" % voice)
	var player: AudioStreamPlayer3D = _busy_player(director)
	assert_not_null(player, "a placed player was given the stream")
	if player != null:
		assert_almost_equal(player.max_distance, director.table.range_m[chop], "heard over the chop's range")
		assert_true(player.stream == first, "the first variant")
	assert_equal(director.voices.sounding(chop, 5000 + 150), 1, "busy for the stream's 200 ms")
	assert_equal(director.voices.sounding(chop, 5000 + 200), 0, "and no longer")
	assert_equal(director.cue(chop, Vector3.ZERO, false, 6000), VoicesScript.PLAYED, "again")
	assert_true(_given_streams(director).has(director.table.streams[chop][1]), "the second variant next")
	clock.free()


func _given_streams(director: DirectorScript) -> Array:
	"""Every stream a placed voice was last given."""
	var streams: Array = []
	for voice: int in director.voices.voice_count():
		if director.voices.placed_player(voice) != null and director.voices.placed_player(voice).stream != null:
			streams.append(director.voices.placed_player(voice).stream)
	return streams


func test_a_staged_file_loads_without_a_warning_and_loops_as_its_cue_says() -> void:
	"""A file that exists is loaded (no warning), the cue is no longer silent, and a looping cue's Ogg is set to
	loop -- the drop-in path the sourcing plan relies on, with a saved stream standing in for a staged file."""
	var path: String = "user://test_demo_sound_loop.tres"
	var ogg := AudioStreamOggVorbis.new()
	ogg.loop = false
	assert_equal(ResourceSaver.save(ogg, path), OK, "a stand-in file saved")
	var spec: Dictionary = _cue("ambience", 0, 1)
	spec["loop"] = true
	spec["files"] = [path, "res://demo/assets/sound/no_such.ogg"]
	var table := SoundTable.new()
	assert_true(table.add(&"drone", spec), "the cue")
	assert_equal(table.load_streams(), 1, "the file that exists is loaded")
	assert_false(table.is_silent(0), "no longer silent")
	assert_true((table.stream_of(0, 0) as AudioStreamOggVorbis).loop, "set to loop")
	assert_equal(table.warnings, 1, "the missing one still warned about, once")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_a_looping_cue_s_files_are_set_to_loop() -> void:
	"""An Ogg or MP3 file on a looping cue is set to loop; on a one-shot, not."""
	var ogg := AudioStreamOggVorbis.new()
	SoundTable._set_looping(ogg, true)
	assert_true(ogg.loop, "looped")
	var mp3 := AudioStreamMP3.new()
	mp3.loop = true
	SoundTable._set_looping(mp3, false)
	assert_false(mp3.loop, "a one-shot does not loop")


func test_the_listener_turns_with_the_camera() -> void:
	"""Facing 180 degrees round, the listener's forward is +Z: left and right follow the view."""
	var director := _director()
	director.set_listener(Vector3.ZERO, 10.0, PI)
	var forward: Vector3 = -director.listener.transform.basis.z
	assert_almost_equal(forward.z, 1.0, "turned round")
	director.set_listener(Vector3.ZERO, 10.0)
	assert_almost_equal((-director.listener.transform.basis.z).z, -1.0, "facing -Z by default")


# --- pause, the U view, distance -----------------------------------------------------------------------

func test_pausing_ducks_ambience_stops_work_and_keeps_cues() -> void:
	"""Paused: Ambience and Water drop by DUCK_DB, the work voices stop and no work starts; a warning still sounds.
	Running again: everything back."""
	var director := _director()
	var chop: int = director.table.row(&"chop")
	assert_equal(director.cue(chop, Vector3.ZERO, false, 1000), VoicesScript.PLAYED, "work sounds")
	var splash: int = director.table.row(&"splash")
	assert_equal(director.cue(splash, Vector3.ZERO, false, 1000), VoicesScript.PLAYED, "a splash sounds")
	var ambience: float = _bus_db(SoundMix.BUS_NAMES[SoundMix.BUS_AMBIENCE])
	director.set_paused(true)
	assert_almost_equal(_bus_db(SoundMix.BUS_NAMES[SoundMix.BUS_AMBIENCE]), ambience + SoundMix.DUCK_DB, "ambience ducked")
	assert_almost_equal(_bus_db(SoundMix.BUS_NAMES[SoundMix.BUS_WATER]),
		SoundMix.percent_db(SoundMix.percents[SoundMix.BUS_WATER]) + SoundMix.DUCK_DB, "water ducked")
	assert_almost_equal(_bus_db(SoundMix.BUS_NAMES[SoundMix.BUS_WORK]),
		SoundMix.percent_db(SoundMix.percents[SoundMix.BUS_WORK]), "work's bus is not ducked: its voices stop")
	assert_equal(director.voices.busy(SoundMix.BUS_WORK, 1001), 0, "work stopped")
	assert_equal(director.cue(chop, Vector3.ZERO, false, 2000), DirectorScript.REFUSE_PAUSED, "no work starts")
	assert_equal(director.voices.busy(SoundMix.BUS_WATER, 1001), 0, "the splash stopped")
	assert_equal(director.cue(splash, Vector3.ZERO, false, 2000), DirectorScript.REFUSE_PAUSED, "no water one-shot starts")
	assert_equal(director.cue(director.table.row(&"warning"), Vector3.ZERO, false, 2000), VoicesScript.PLAYED, "a cue does")
	director.set_paused(false)
	assert_almost_equal(_bus_db(SoundMix.BUS_NAMES[SoundMix.BUS_AMBIENCE]), ambience, "ambience back")
	assert_equal(director.cue(chop, Vector3.ZERO, false, 3000), VoicesScript.PLAYED, "work again")


func test_the_clock_drives_the_pause() -> void:
	"""Bound to a clock, the director follows its effective speed: 0 ducks, any other speed does not."""
	var director := _director()
	var clock := GameManagerScript.new()
	clock.start_game()
	director.bind(null, clock, Callable())
	assert_true(clock.set_speed(4), "4x")
	director.update(1000, 0.016)
	assert_false(director.mix.paused, "running at 4x")
	clock.pause_game()
	director.update(1016, 0.016)
	assert_true(director.mix.paused, "paused")
	clock.free()


func test_the_u_view_switches_the_underground_filter() -> void:
	"""U view on: the world above (Ambience, Water, Work Surface) through the low-pass, the work below clear; off:
	only the work below is muffled."""
	var director := _director()
	var under: Array[bool] = [false]
	director.bind(null, null, func() -> bool: return under[0])
	director.update(1000, 0.016)
	assert_false(SoundMix.filtered(SoundMix.BUS_NAMES[SoundMix.BUS_AMBIENCE]), "above: ambience clear")
	assert_false(SoundMix.filtered(SoundMix.WORK_SURFACE), "above: surface work clear")
	assert_true(SoundMix.filtered(SoundMix.WORK_UNDER), "above: digging below muffled")
	under[0] = true
	director.update(1016, 0.016)
	assert_true(SoundMix.filtered(SoundMix.BUS_NAMES[SoundMix.BUS_AMBIENCE]), "U view: ambience muffled")
	assert_true(SoundMix.filtered(SoundMix.BUS_NAMES[SoundMix.BUS_WATER]), "U view: water muffled")
	assert_true(SoundMix.filtered(SoundMix.WORK_SURFACE), "U view: surface work muffled")
	assert_false(SoundMix.filtered(SoundMix.WORK_UNDER), "U view: digging clear")
	assert_false(SoundMix.filtered(SoundMix.BUS_NAMES[SoundMix.BUS_CUES]), "alerts are never filtered")


func test_a_far_cue_takes_no_voice_and_zooming_out_lifts_the_listener() -> void:
	"""The listener stands over the focus, 0.4 of the zoom up: zoomed in a footstep at the focus is heard; zoomed
	out to 70 m it is beyond its 14 m and takes no voice; a flat alert is heard anywhere."""
	var director := _director()
	var step: int = director.table.row(&"step_grass")
	director.set_listener(Vector3(2.0, 0.0, 3.0), 10.0)
	assert_almost_equal(director.listener_at().y, 4.0, "4 m up at a 10 m zoom")
	assert_equal(director.cue(step, Vector3(2.0, 0.0, 3.0), false, 1000), VoicesScript.PLAYED, "heard close")
	director.set_listener(Vector3(2.0, 0.0, 3.0), 70.0)
	assert_equal(director.cue(step, Vector3(2.0, 0.0, 3.0), false, 2000), DirectorScript.REFUSE_FAR, "zoomed out")
	assert_equal(director.cue(director.table.row(&"warning"), Vector3(500.0, 0.0, 0.0), false, 2000),
		VoicesScript.PLAYED, "an alert is flat")


# --- settings ---------------------------------------------------------------------------------------

func test_settings_move_the_bus_volumes_and_mute() -> void:
	"""+ and the slider set a bus's percent in 5 % steps and the bus follows; Mute silences it and keeps its volume."""
	var director := _director()
	var settings := SettingsScript.new()
	_nodes.append(settings)
	settings.apply = director.mix.apply
	var work: StringName = SoundMix.BUS_NAMES[SoundMix.BUS_WORK]
	settings.up_button(SoundMix.BUS_WORK).pressed.emit()
	assert_equal(SoundMix.percents[SoundMix.BUS_WORK], 80, "75 -> 80")
	assert_almost_equal(_bus_db(work), linear_to_db(0.8), "the bus at 80 %")
	settings.slider(SoundMix.BUS_WORK).value_changed.emit(42.0)
	assert_equal(SoundMix.percents[SoundMix.BUS_WORK], 40, "the slider snaps to 40")
	assert_almost_equal(_bus_db(work), linear_to_db(0.4), "the bus at 40 %")
	settings.mute_button(SoundMix.BUS_WORK).button_pressed = true
	assert_true(AudioServer.is_bus_mute(AudioServer.get_bus_index(work)), "muted")
	assert_equal(settings.mute_button(SoundMix.BUS_WORK).text, SettingsScript.MUTED_TEXT, "says so")
	assert_equal(SoundMix.percents[SoundMix.BUS_WORK], 40, "its volume kept")
	settings.mute_button(SoundMix.BUS_WORK).button_pressed = false
	assert_false(AudioServer.is_bus_mute(AudioServer.get_bus_index(work)), "unmuted")
	SoundMix.set_percent(SoundMix.BUS_MASTER, 0)
	director.mix.apply()
	assert_true(AudioServer.is_bus_mute(AudioServer.get_bus_index(&"Master")), "0 % is silence")


func test_down_is_refused_at_silence_and_up_at_full() -> void:
	"""− is disabled at 0 %, + at 100 %, each saying why."""
	var settings := SettingsScript.new()
	_nodes.append(settings)
	settings.set_percent(SoundMix.BUS_CUES, 0)
	assert_true(settings.down_button(SoundMix.BUS_CUES).disabled, "− off at 0")
	settings.set_percent(SoundMix.BUS_CUES, 100)
	assert_true(settings.up_button(SoundMix.BUS_CUES).disabled, "+ off at 100")
	assert_equal(settings.up_button(SoundMix.BUS_CUES).tooltip_text, "Already at full volume", "saying why")
	assert_false(settings.down_button(SoundMix.BUS_CUES).disabled, "− back")
	assert_true(settings.down_button(SoundMix.BUS_CUES).tooltip_text.begins_with("Lower"), "with its own tooltip")
	settings.set_percent(SoundMix.BUS_CUES, 50)
	assert_true(settings.up_button(SoundMix.BUS_CUES).tooltip_text.begins_with("Raise"), "+ has its tooltip back")


func test_quiet_focus_sets_the_mix_and_a_custom_volume_unlights_it() -> void:
	"""Quiet focus: alerts forward, the world down, its button lit; moving one volume makes the mix the player's."""
	var director := _director()
	var settings := SettingsScript.new()
	_nodes.append(settings)
	settings.apply = director.mix.apply
	assert_true(settings.preset_button(SoundMix.PRESET_BALANCED).button_pressed, "Balanced lit at first")
	settings.preset_button(SoundMix.PRESET_QUIET).pressed.emit()
	assert_equal(SoundMix.percents, SoundMix.QUIET_PERCENTS, "the quiet mix")
	assert_true(SoundMix.percents[SoundMix.BUS_CUES] > SoundMix.BALANCED_PERCENTS[SoundMix.BUS_CUES], "alerts up")
	assert_true(SoundMix.percents[SoundMix.BUS_WORK] < SoundMix.BALANCED_PERCENTS[SoundMix.BUS_WORK], "work down")
	assert_almost_equal(_bus_db(SoundMix.BUS_NAMES[SoundMix.BUS_AMBIENCE]), linear_to_db(0.2), "on the bus")
	assert_true(settings.preset_button(SoundMix.PRESET_QUIET).button_pressed, "lit")
	assert_false(settings.preset_button(SoundMix.PRESET_BALANCED).button_pressed, "Balanced not")
	settings.step(SoundMix.BUS_WATER, 5)
	assert_equal(SoundMix.preset, SoundMix.PRESET_CUSTOM, "custom")
	assert_false(settings.preset_button(SoundMix.PRESET_QUIET).button_pressed, "nothing lit")
	settings.step(SoundMix.BUS_WATER, -5)
	assert_equal(SoundMix.preset, SoundMix.PRESET_QUIET, "back on the quiet mix: lit again")


func test_the_settings_outlast_the_menu_as_the_interface_scale_does() -> void:
	"""Set once, a new menu (a Restart's) shows them: they are the session's, like the interface scale."""
	var first := SettingsScript.new()
	_nodes.append(first)
	first.set_percent(SoundMix.BUS_AMBIENCE, 35)
	first.set_muted(true, SoundMix.BUS_CUES)
	var again := SettingsScript.new()
	_nodes.append(again)
	assert_almost_equal(again.slider(SoundMix.BUS_AMBIENCE).value, 35.0, "the volume")
	assert_true(again.mute_button(SoundMix.BUS_CUES).button_pressed, "the mute")


func test_the_menu_settings_page_offers_sound_and_says_it_is_silent() -> void:
	"""The Settings page carries the sound section, no "no sound yet" line, and the note says what is true."""
	var menu := MenuScript.new()
	_nodes.append(menu)
	menu.sound.set_silent(true)
	var text: String = menu.page_text(MenuScript.PAGE_SETTINGS)
	assert_true(text.contains(SettingsScript.TITLE), "a Sound heading")
	for bus: int in SoundMix.BUS_COUNT:
		assert_true(text.contains(SoundMix.BUS_LABELS[bus]), "%s row" % SoundMix.BUS_LABELS[bus])
	assert_true(text.contains(SoundMix.PRESET_NAMES[SoundMix.PRESET_QUIET]), "Quiet focus offered")
	assert_false(text.contains("no sound yet"), "no 'no sound yet' line")
	assert_true(menu.sound.note_text().contains(SettingsScript.SILENT_NOTE), "silent, said")
	menu.sound.set_silent(false)
	assert_false(menu.sound.note_text().contains(SettingsScript.SILENT_NOTE), "not once files are in")
	assert_true(menu.sound.note_text().contains(SettingsScript.MATCH_NOTE), "the equivalence promise stays")


# --- the event map: completed events only --------------------------------------------------------------

func _taps_for(brains: Array[BrainScript]) -> TapsScript:
	"""An event map over the shipped table and these residents, baseline taken at 0 ms."""
	var taps := TapsScript.new()
	taps.bind_table(_shipped())
	taps.brains = brains
	taps.watch()
	return taps


func _events(taps: TapsScript, c: int) -> int:
	"""How many of this frame's events are C_* `c`."""
	var n: int = 0
	for k: int in taps.event_count:
		if taps.event_row[k] == taps.cue_row(c):
			n += 1
	return n


func test_nothing_sounds_for_what_already_stood_when_watching_began() -> void:
	"""A resident already carrying and in the water when the map begins raises no pickup, no water_in."""
	var brain := BrainScript.new()
	brain.carrying = true
	brain.in_water = true
	var taps := _taps_for([brain] as Array[BrainScript])
	assert_equal(taps.poll(16, Vector2.ZERO), 0, "nothing")


func test_a_carry_sounds_pickup_and_drop_once_each() -> void:
	"""The carry begins: one pickup; it goes on: nothing; it ends: one drop."""
	var brain := BrainScript.new()
	var taps := _taps_for([brain] as Array[BrainScript])
	brain.carrying = true
	taps.poll(16, Vector2.ZERO)
	assert_equal(_events(taps, TapsScript.C_PICKUP), 1, "pickup")
	taps.poll(32, Vector2.ZERO)
	assert_equal(taps.event_count, 0, "carrying on: nothing")
	brain.carrying = false
	taps.poll(48, Vector2.ZERO)
	assert_equal(_events(taps, TapsScript.C_DROP), 1, "drop")


func test_a_strike_sounds_only_once_the_work_has_begun_and_a_beat_is_done() -> void:
	"""Walking to the tree: no chop, however long; the fell begun but short of a beat: none; a beat: one; three beats
	in one frame: still one; the beaver's are gnaws."""
	var made: Array = _fellers(1)
	var jobs: JobsScript = made[1]
	var taps := _taps_for(made[0])
	taps.jobs = jobs
	jobs.step[0] = 0
	jobs.issued[0] = 0
	jobs.elapsed_usec[0] = 5 * TapsScript.STRIKE_USEC
	taps.poll(16, Vector2.ZERO)
	assert_equal(taps.event_count, 0, "a walk never strikes")
	jobs.step[0] = 1
	taps.poll(24, Vector2.ZERO)
	assert_equal(taps.event_count, 0, "at the fell, not yet begun (its opening check not passed): no chop")
	jobs.issued[0] = 1
	jobs.elapsed_usec[0] = TapsScript.STRIKE_USEC - 1
	taps.poll(32, Vector2.ZERO)
	assert_equal(taps.event_count, 0, "short of a beat")
	jobs.elapsed_usec[0] = TapsScript.STRIKE_USEC
	taps.poll(48, Vector2.ZERO)
	assert_equal(_events(taps, TapsScript.C_CHOP), 1, "a beat done: chop")
	jobs.elapsed_usec[0] = 4 * TapsScript.STRIKE_USEC
	taps.poll(64, Vector2.ZERO)
	assert_equal(_events(taps, TapsScript.C_CHOP), 1, "three beats in a frame: one chop")
	taps.poll(80, Vector2.ZERO)
	assert_equal(taps.event_count, 0, "no beat since: nothing")


func test_a_beaver_fells_by_gnawing() -> void:
	"""The beaver's felling beats sound as gnaws, a mouse's as chops (forest_skills.gd `gnaws_wood`)."""
	var made: Array = _fellers(2)
	var skills := SkillsScript.new()
	skills.setup([&"beaver_bridgewright", &"mouse"] as Array[StringName], PackedStringArray(["beaver", "mouse"]))
	var taps := _taps_for(made[0])
	taps.jobs = made[1]
	taps.skills = skills
	taps.watch()
	var jobs: JobsScript = made[1]
	jobs.elapsed_usec[0] = TapsScript.STRIKE_USEC
	jobs.elapsed_usec[1] = TapsScript.STRIKE_USEC
	taps.poll(16, Vector2.ZERO)
	assert_equal(_events(taps, TapsScript.C_GNAW), 1, "the beaver gnaws")
	assert_equal(_events(taps, TapsScript.C_CHOP), 1, "the mouse chops")


func test_sawing_strokes_and_grubbing_digs() -> void:
	"""A saw step strokes every STROKE_USEC; a grub strikes as a dig."""
	var made: Array = _fellers(2)
	var jobs: JobsScript = made[1]
	jobs.kind[0] = JobsScript.KIND_SAW
	jobs.step[0] = 3
	jobs.kind[1] = JobsScript.KIND_GRUB
	jobs.step[1] = 1
	var taps := _taps_for(made[0])
	taps.jobs = jobs
	taps.watch()
	jobs.elapsed_usec[0] = TapsScript.STROKE_USEC
	jobs.elapsed_usec[1] = TapsScript.STRIKE_USEC
	taps.poll(16, Vector2.ZERO)
	assert_equal(_events(taps, TapsScript.C_SAW), 1, "a saw stroke")
	assert_equal(_events(taps, TapsScript.C_DIG), 1, "a grubbing spade")


func test_a_tree_sounds_its_fall_only_when_it_falls() -> void:
	"""The stand unchanged: nothing; felled (standing -> stump): one tree_fall, at the tree."""
	var stand := StandScript.new()
	var placements: Array[Dictionary] = [{"key": &"oak_mature", "at": Vector2(-10.0, -24.0), "yaw": 0.0, "size": 1.0},
		{"key": &"beech_mature", "at": Vector2(0.0, -24.0), "yaw": 0.0, "size": 1.0}]
	assert_true(stand.bind_into(placements, WOOD, 1, _read), "bound")
	var taps := _taps_for([] as Array[BrainScript])
	taps.stand = stand
	taps.watch()
	taps.poll(16, Vector2.ZERO)
	assert_equal(taps.event_count, 0, "standing")
	assert_true(stand.fell_into(0, 5, Vector2.UP, false, _read), "felled")
	taps.poll(32, Vector2.ZERO)
	assert_equal(_events(taps, TapsScript.C_TREE_FALL), 1, "it falls")
	assert_almost_equal(taps.event_at[0].x, -10.0, "at the tree")
	taps.poll(48, Vector2.ZERO)
	assert_equal(taps.event_count, 0, "once")
	assert_true(stand.fell_into(1, 6, Vector2.UP, false, _read), "the second felled")
	taps.poll(64, Vector2.ZERO)
	assert_equal(_events(taps, TapsScript.C_TREE_FALL), 1, "only the second falls: the first stump is not new")
	assert_almost_equal(taps.event_at[0].x, 0.0, "at the second tree")
	assert_true(stand.grub_into(0, _read), "the first stump grubbed out")
	taps.poll(80, Vector2.ZERO)
	assert_equal(taps.event_count, 0, "a stump grubbed is no fall")


func test_a_tree_blown_down_falls_too() -> void:
	"""A storm's blow-down goes straight from standing to cleared; it falls all the same."""
	var stand := StandScript.new()
	var placements: Array[Dictionary] = [{"key": &"oak_mature", "at": Vector2(-10.0, -24.0), "yaw": 0.0, "size": 1.0}]
	assert_true(stand.bind_into(placements, WOOD, 1, _read), "bound")
	var taps := _taps_for([] as Array[BrainScript])
	taps.stand = stand
	taps.watch()
	assert_true(stand.blow_down_into(0, 5, Vector2.UP, _read), "blown down")
	assert_equal(stand.state_of(0), StandScript.STATE_CLEARED, "cleared at once")
	taps.poll(16, Vector2.ZERO)
	assert_equal(_events(taps, TapsScript.C_TREE_FALL), 1, "it falls")


func test_a_dig_sounds_each_cut_and_completes_on_opening() -> void:
	"""Dig time short of a cut: nothing; a cut done: one dig, at the digger, below; the segment open: complete."""
	var ground := GroundScript.new()
	ground.cells.fill(GroundScript.LOAM)
	var network := GraphScript.new()
	network.set_ground(ground)
	var ref := PackedInt32Array([-1, 0, -1])
	assert_true(network.add_into(PackedInt32Array([512, 512, 12800, 512]), 2, 0, ref), "a tunnel")
	var digger := BrainScript.new()
	digger.position = Vector2(1.0, 0.5)
	network.digger[0] = 0
	var taps := _taps_for([digger] as Array[BrainScript])
	taps.network = network
	taps.watch()
	network.advance(0, network.generation[0], 1000)
	taps.poll(16, Vector2.ZERO)
	assert_equal(_events(taps, TapsScript.C_DIG), 0, "no cut yet")
	network.advance(0, network.generation[0], 5 * Rules.USEC_PER_SECOND)
	taps.poll(32, Vector2.ZERO)
	assert_equal(_events(taps, TapsScript.C_DIG), 1, "a cut: dig")
	assert_equal(taps.event_below[0], 1, "below")
	network.advance(0, network.generation[0], 100000)
	taps.poll(40, Vector2.ZERO)
	assert_equal(_events(taps, TapsScript.C_DIG), 0, "more dig time, no new cut: nothing")
	network.advance(0, network.generation[0], 1000000000)
	taps.poll(48, Vector2.ZERO)
	assert_equal(_events(taps, TapsScript.C_COMPLETE), 1, "open: complete")
	taps.poll(64, Vector2.ZERO)
	assert_equal(_events(taps, TapsScript.C_COMPLETE), 0, "once: an open segment is not opening again")


func test_a_bridge_completes_once_when_it_opens() -> void:
	"""A planned bridge opening chimes complete once; a bridge already open, or a new plan, does not."""
	var bridges := BridgesScript.new()
	bridges.phase[0] = BridgesScript.PHASE_PLANNED
	bridges.phase[1] = BridgesScript.PHASE_OPEN
	var taps := _taps_for([] as Array[BrainScript])
	taps.bridges = bridges
	taps.watch()
	taps.poll(16, Vector2.ZERO)
	assert_equal(taps.event_count, 0, "nothing opened")
	bridges.phase[0] = BridgesScript.PHASE_OPEN
	taps.poll(32, Vector2.ZERO)
	assert_equal(_events(taps, TapsScript.C_COMPLETE), 1, "opened")
	bridges.phase[2] = BridgesScript.PHASE_PLANNED
	taps.poll(48, Vector2.ZERO)
	assert_equal(taps.event_count, 0, "a new plan is no completion")
	bridges.generation[2] += 1
	bridges.phase[2] = BridgesScript.PHASE_OPEN
	taps.poll(64, Vector2.ZERO)
	assert_equal(taps.event_count, 0, "a different bridge (a new generation) found open is not this one opening")


func test_a_new_warning_chimes_and_a_note_or_a_folded_repeat_does_not() -> void:
	"""A note: nothing; a warning: the warning cue; the same warning again (folded ×2): nothing."""
	var notices := NoticesScript.new()
	var taps := _taps_for([] as Array[BrainScript])
	taps.notices = notices
	taps.watch()
	taps.poll(Time.get_ticks_msec(), Vector2.ZERO)
	assert_equal(taps.event_count, 0, "nothing posted: nothing")
	notices.post(NoticesScript.SOURCE_FARM, NoticesScript.LEVEL_NOTE, "Beans sown")
	taps.poll(Time.get_ticks_msec(), Vector2.ZERO)
	assert_equal(taps.event_count, 0, "a note is silent")
	notices.post(NoticesScript.SOURCE_TUNNELS, NoticesScript.LEVEL_WARNING, "Tunnel 1 flooded")
	taps.poll(Time.get_ticks_msec(), Vector2.ZERO)
	assert_equal(_events(taps, TapsScript.C_WARNING), 1, "a warning chimes")
	taps.poll(Time.get_ticks_msec(), Vector2.ZERO)
	assert_equal(taps.event_count, 0, "once")
	notices.post(NoticesScript.SOURCE_TUNNELS, NoticesScript.LEVEL_WARNING, "Tunnel 1 flooded")
	assert_equal(notices.repeats(0), 2, "the feed folded it")
	taps.poll(Time.get_ticks_msec(), Vector2.ZERO)
	assert_equal(taps.event_count, 0, "a repeat does not chime again")
	notices.post(NoticesScript.SOURCE_FARM, NoticesScript.LEVEL_NOTE, "Peas up")
	taps.poll(Time.get_ticks_msec(), Vector2.ZERO)
	assert_equal(taps.event_count, 0, "a later note does not raise the old warning again")
	notices.post(NoticesScript.SOURCE_WEATHER, NoticesScript.LEVEL_WARNING, "Frost tonight")
	notices.post(NoticesScript.SOURCE_WEATHER, NoticesScript.LEVEL_WARNING, "Frost tonight")
	taps.poll(Time.get_ticks_msec(), Vector2.ZERO)
	assert_equal(_events(taps, TapsScript.C_WARNING), 1, "a new warning folded in the same frame still chimes")
	notices.post(NoticesScript.SOURCE_EVENTS, NoticesScript.LEVEL_WARNING, "Fire")
	notices.post(NoticesScript.SOURCE_FARM, NoticesScript.LEVEL_NOTE, "Beans sown")
	taps.poll(Time.get_ticks_msec(), Vector2.ZERO)
	assert_equal(_events(taps, TapsScript.C_WARNING), 1, "a warning under a later note in one frame chimes")


func test_water_edges_and_a_splash_as_swimming_begins() -> void:
	"""In: water_in; wading: no splash; swimming: splash; treading on: nothing; out: water_out."""
	var brain := BrainScript.new()
	var swim := SwimStateScript.new()
	swim.setup(PackedStringArray(["otter"]), PackedInt32Array([1024]))
	var taps := _taps_for([brain] as Array[BrainScript])
	taps.swim = swim
	taps.watch()
	brain.in_water = true
	swim.mode[0] = SwimStateScript.MODE_WADE
	taps.poll(16, Vector2.ZERO)
	assert_equal(_events(taps, TapsScript.C_WATER_IN), 1, "in")
	assert_equal(_events(taps, TapsScript.C_SPLASH), 0, "wading: no splash")
	swim.mode[0] = SwimStateScript.MODE_SWIM
	taps.poll(32, Vector2.ZERO)
	assert_equal(_events(taps, TapsScript.C_SPLASH), 1, "swimming: splash")
	swim.mode[0] = SwimStateScript.MODE_TREAD
	taps.poll(48, Vector2.ZERO)
	assert_equal(taps.event_count, 0, "still in deep water: nothing")
	brain.in_water = false
	swim.mode[0] = SwimStateScript.MODE_LAND
	taps.poll(64, Vector2.ZERO)
	assert_equal(_events(taps, TapsScript.C_WATER_OUT), 1, "out")


func _walk(taps: TapsScript, brain: BrainScript, from: Vector2, to: Vector2, frames: int) -> int:
	"""Walk `brain` from `from` to `to` over `frames` polls; returns the footsteps raised."""
	var steps: int = 0
	for f: int in frames + 1:
		brain.position = from.lerp(to, float(f) / float(frames))
		taps.poll(1000 + f * 16, Vector2.ZERO)
		for c: int in [TapsScript.C_STEP_GRASS, TapsScript.C_STEP_DIRT, TapsScript.C_STEP_WOOD,
				TapsScript.C_STEP_TUNNEL, TapsScript.C_STEP_WADE]:
			steps += _events(taps, c)
	return steps


func test_footsteps_follow_the_ground_underfoot() -> void:
	"""Each whole stride sounds once, by the ground: grass, a worn path's dirt, a bridge leg's wood, a tunnel; a
	swimmer takes no steps; a placement (a long jump) none either."""
	var brain := BrainScript.new()
	var taps := _taps_for([brain] as Array[BrainScript])
	var off_path := _grass_point()
	brain.position = off_path
	taps.watch()
	var steps: int = _walk(taps, brain, off_path, off_path + Vector2(0.95, 0.0), 19)
	assert_equal(steps, 2, "0.95 m: two strides")
	brain.underground = true
	brain.position = off_path + Vector2(1.45, 0.0)
	taps.poll(2016, Vector2.ZERO)
	assert_equal(_events(taps, TapsScript.C_STEP_TUNNEL), 1, "below: the tunnel's floor")
	brain.underground = false
	brain.state = BrainScript.State.CROSS
	brain.position = off_path + Vector2(1.95, 0.0)
	taps.poll(2032, Vector2.ZERO)
	assert_equal(_events(taps, TapsScript.C_STEP_WOOD), 1, "a bridge leg: wood")
	brain.state = BrainScript.State.WALK
	brain.position = off_path + Vector2(2.45, 0.0)
	taps.poll(2040, Vector2.ZERO)
	assert_equal(_events(taps, TapsScript.C_STEP_GRASS), 1, "grass again")
	brain.in_water = true
	brain.position = off_path + Vector2(2.95, 0.0)
	taps.poll(2048, Vector2.ZERO)
	assert_equal(taps.event_count, 1, "swimming: only the water_in, no step")
	brain.in_water = false
	brain.position = off_path + Vector2(12.0, 0.0)
	taps.poll(2064, Vector2.ZERO)
	assert_equal(_events(taps, TapsScript.C_STEP_GRASS), 0, "a jump is no stride")


func _grass_point() -> Vector2:
	"""A spot well off every worn path, with room to walk 3 m east on grass."""
	for z: int in range(-19, 20):
		for x: int in range(-19, 15):
			var p := Vector2(float(x), float(z))
			if WorldLayout.path_distance(p) > 1.0 and WorldLayout.path_distance(p + Vector2(3.0, 0.0)) > 1.0 \
					and WorldLayout.path_distance(p + Vector2(1.5, 0.0)) > 1.0:
				return p
	return Vector2(-19.0, 19.0)


func test_wading_steps_splash_softly() -> void:
	"""A resident wading (swim mode WADE, not yet in deep water) takes wading steps."""
	var brain := BrainScript.new()
	var swim := SwimStateScript.new()
	swim.setup(PackedStringArray(["mouse"]), PackedInt32Array([1024]))
	var taps := _taps_for([brain] as Array[BrainScript])
	taps.swim = swim
	brain.position = _grass_point()
	taps.watch()
	swim.mode[0] = SwimStateScript.MODE_WADE
	brain.position += Vector2(0.5, 0.0)
	taps.poll(16, Vector2.ZERO)
	assert_equal(_events(taps, TapsScript.C_STEP_WADE), 1, "a wading step")
	assert_equal(_events(taps, TapsScript.C_STEP_GRASS), 0, "not grass")


func test_a_work_begun_again_strikes_from_its_first_beat() -> void:
	"""A row's work taken back to fewer beats (the row reused, or the step begun again) strikes again at its next
	whole beat, not only once it passes the old count."""
	var made: Array = _fellers(1)
	var jobs: JobsScript = made[1]
	var taps := _taps_for(made[0])
	taps.jobs = jobs
	taps.watch()
	jobs.elapsed_usec[0] = 3 * TapsScript.STRIKE_USEC
	taps.poll(16, Vector2.ZERO)
	assert_equal(_events(taps, TapsScript.C_CHOP), 1, "three beats: a chop")
	jobs.elapsed_usec[0] = 0
	taps.poll(32, Vector2.ZERO)
	assert_equal(taps.event_count, 0, "begun again: nothing yet")
	jobs.elapsed_usec[0] = TapsScript.STRIKE_USEC
	taps.poll(48, Vector2.ZERO)
	assert_equal(_events(taps, TapsScript.C_CHOP), 1, "its first beat strikes")


func test_a_worn_path_sounds_as_dirt() -> void:
	"""On a worn path (world_layout.gd's capsules) a stride is dirt."""
	var brain := BrainScript.new()
	var taps := _taps_for([brain] as Array[BrainScript])
	var on_path := _a_path_point(taps)
	brain.position = on_path
	taps.watch()
	brain.position = on_path + Vector2(0.0, 0.46)
	taps.poll(16, Vector2.ZERO)
	var dirt: int = _events(taps, TapsScript.C_STEP_DIRT)
	var grass: int = _events(taps, TapsScript.C_STEP_GRASS)
	assert_equal(dirt + grass, 1, "one stride")
	assert_equal(dirt, 1 if taps.is_dirt(brain.position) else 0, "dirt on the path")
	assert_true(taps.is_dirt(on_path), "the path's middle is dirt")
	assert_false(taps.is_dirt(_grass_point()), "the grass is not")


func _a_path_point(taps: TapsScript) -> Vector2:
	"""The middle of the first worn path segment."""
	var seg: Vector4 = WorldLayout.PATH_SEGMENTS[0]
	return Vector2((seg.x + seg.z) * 0.5, (seg.y + seg.w) * 0.5)


func test_ambience_follows_the_weather_and_the_nearest_bank() -> void:
	"""Clear: a light wind, no rain; a downpour hour: rain at full and more wind; the stream heard from the bank
	nearest the listener (the village's stream runs down the east edge)."""
	var weather := WeatherScript.new()
	var taps := _taps_for([] as Array[BrainScript])
	taps.weather = weather
	taps.water_map = WaterLayout.make_map()
	weather.observe(1, 5, 15, 200, 0, 0)
	taps.poll(1000, Vector2.ZERO)
	assert_equal(weather.condition(), WeatherScript.COND_CLEAR, "clear")
	assert_equal(taps.wind_permille, TapsScript.WIND_BY_CONDITION[WeatherScript.COND_CLEAR], "light wind")
	assert_equal(taps.rain_permille, 0, "no rain")
	assert_equal(taps.stream_permille, 1000, "the stream is there")
	assert_true(taps.stream_at.x > 10.0, "east of the village (%.1f)" % taps.stream_at.x)
	weather.observe(1, 5, 15, 200, WeatherScript.DOWNPOUR_RAIN, 0)
	taps.poll(1100, Vector2.ZERO)
	assert_equal(taps.rain_permille, 0, "not read again within AMBIENCE_MS")
	taps.poll(1000 + TapsScript.AMBIENCE_MS, Vector2.ZERO)
	assert_equal(weather.condition(), WeatherScript.COND_RAIN, "raining")
	assert_equal(taps.rain_permille, TapsScript.RAIN_DOWNPOUR, "a downpour")
	assert_true(taps.wind_permille > TapsScript.WIND_BY_CONDITION[WeatherScript.COND_CLEAR], "more wind")


func test_the_loops_ease_towards_the_map_s_levels() -> void:
	"""The director's loops move towards the map's levels at FADE_PERMILLE_PER_S, not at once."""
	var director := _director()
	director.taps.rain_permille = 1000
	director.taps.wind_permille = 0
	director.taps.stream_permille = 0
	director._ease_loops(0.5)
	assert_almost_equal(director.loop_level(DirectorScript.LOOP_RAIN), 300.0, "half a second: 300")
	director._ease_loops(5.0)
	assert_almost_equal(director.loop_level(DirectorScript.LOOP_RAIN), 1000.0, "then all the way")


func test_ui_buttons_click_once_hooked_and_only_once() -> void:
	"""A watched button's press sounds ui_click; watching it again hooks nothing more."""
	var director := _director()
	var root := VBoxContainer.new()
	_nodes.append(root)
	var button := Button.new()
	root.add_child(button)
	assert_equal(director.watch_buttons(root), 1, "one button hooked")
	assert_equal(director.watch_buttons(root), 0, "not twice")
	button.pressed.emit()
	assert_equal(director.voices.played[director.table.row(&"ui_click")], 1, "clicked")
