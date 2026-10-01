extends Node3D
## THE live demo's sound owner: one node under the village that holds the table, the mix, the voices, the
## ambience loops and the listener, and plays the event map each frame. Decision 0351 (review F43, P8, UX-029,
## UX-031). Presentation only.
##
## WHY NOT AN AUTOLOAD. The project has five autoloads (EntityManager, GameManager, SettlementSystem,
## EconomySystem, UIManager) and a cap of six (CLAUDE.md); ARCH-GODOT-001 plans AudioManager as the settlement's
## "optional presentation" service. Everything this owner hears is the DEMO's -- its cast, woods, tunnels,
## water, notice feed and camera -- none of which exists outside the demo scene. Spending the last autoload
## slot on demo state would leave a global that points at nothing in the game, and a Restart would have to
## rebind it. So the demo's sound is scene-scoped, made and freed with the village; the later AudioManager can
## take this table, mix and voice pool over unchanged, because none of them reads a demo model.
##
## EACH FRAME (`_process`, real time): the listener follows the camera; the clock's pause and the U view set
## the mix; the event map (sound_taps.gd) is read and each event offered to the voices (sound_voices.gd);
## the ambience loops ease towards the map's levels.
##
## THE LISTENER sits over the camera's focus, LISTENER_LIFT of the zoom distance up, turned with the camera's
## heading (so a sound on the screen's left is heard on the left whichever way the view faces): zoomed in, the work at
## the focus is close; zoomed out to the woods, the listener rises out of the work's range and the village
## settles to its ambience (UX-029's calm bed). A placed cue farther from the listener than its range is not
## given a voice at all (REFUSE_FAR), so distant work never takes one from near work.
##
## PAUSED (the clock's effective speed is 0): the Ambience and Water buses duck (sound_mix.gd), every Work and
## Water one-shot is stopped and none starts; Cues still sound (a warning raised while paused, a click).
## SPEED never reaches a player: gaps are real time, so 4x sounds no denser than its gaps allow and no pitch
## changes (sound_voices.gd).

const SoundTable := preload("res://demo/sound/sound_table.gd")
const SoundMix := preload("res://demo/sound/sound_mix.gd")
const VoicesScript := preload("res://demo/sound/sound_voices.gd")
const TapsScript := preload("res://demo/sound/sound_taps.gd")
const DemoCameraScript := preload("res://demo/camera/demo_camera.gd")
const GameManagerScript := preload("res://scripts/systems/game_manager.gd")
const DemoCastScript := preload("res://demo/cast/demo_cast.gd")
const DemoActorScript := preload("res://demo/cast/demo_actor.gd")
const ForestryScript := preload("res://demo/forestry/demo_forestry.gd")
const GraphScript := preload("res://demo/tunnel/underground_graph.gd")
const WaterplayScript := preload("res://demo/waterplay/demo_waterplay.gd")
const ServicesScript := preload("res://demo/demo_services.gd")
const WaterMapScript := preload("res://demo/water/water_map.gd")

const REFUSE_PAUSED: int = 10
const REFUSE_FAR: int = 11
const REFUSE_NO_CUE: int = 12
## The listener stands this share of the camera's distance above its focus.
const LISTENER_LIFT: float = 0.4
## Ambience loops ease their level this much (per mille) per real second.
const FADE_PERMILLE_PER_S: float = 600.0
## The loops the director keeps, by table id: the map's three ambience levels.
const LOOP_IDS: Array[StringName] = [&"amb_wind", &"amb_rain", &"amb_stream"]
const LOOP_WIND: int = 0
const LOOP_RAIN: int = 1
const LOOP_STREAM: int = 2

var table: SoundTable = SoundTable.new()
var mix: SoundMix = SoundMix.new()
var voices: VoicesScript = VoicesScript.new()
var taps: TapsScript = TapsScript.new()
var listener: AudioListener3D = AudioListener3D.new()
## The last frame's cost, microseconds (the cost check).
var frame_usec: int = 0

var _camera: DemoCameraScript = null
var _clock: GameManagerScript = null
var _view_on: Callable = Callable()
var _loop_row: PackedInt32Array = PackedInt32Array([-1, -1, -1])
var _loop_level: PackedFloat32Array = PackedFloat32Array([0.0, 0.0, 0.0])
var _loop_target: PackedInt32Array = PackedInt32Array([0, 0, 0])
var _loop_flat: Array[AudioStreamPlayer] = [null, null, null]
var _loop_placed: AudioStreamPlayer3D = null
var _listener_ground: Vector2 = Vector2.ZERO
var _listener_at: Vector3 = Vector3.ZERO
var _click_row: int = -1


func _init() -> void:
	"""Named; the voices and the listener as children."""
	name = "SoundDirector"
	add_child(voices)
	add_child(listener)


func configure(table_path: String = SoundTable.DEFAULT_PATH) -> bool:
	"""Read the table, make the buses and apply the mix, build the voice pool and the loops, and resolve the
	event map's cues. False when the table could not be read (the demo then runs silent, warned once)."""
	var ok: bool = table.load_from(table_path)
	if not ok:
		push_warning("demo sound: %s; %s" % ["; ".join(table.errors),
			"the demo runs silent" if table.count() == 0 else "those cues are left out"])
	mix.ensure_buses()
	mix.apply()
	voices.build(table)
	taps.bind_table(table)
	_click_row = table.row(&"ui_click")
	_build_loops()
	return ok


func _build_loops() -> void:
	"""One player per ambience loop in the table (once): placed for the stream, flat for wind and rain."""
	for k: int in LOOP_IDS.size():
		_loop_row[k] = table.row(LOOP_IDS[k])
		if _loop_row[k] < 0:
			continue
		var bus_name: StringName = SoundMix.BUS_NAMES[table.bus[_loop_row[k]]]
		if k == LOOP_STREAM and _loop_placed == null:
			_loop_placed = AudioStreamPlayer3D.new()
			_loop_placed.bus = bus_name
			_loop_placed.max_distance = table.range_m[_loop_row[k]]
			add_child(_loop_placed)
		elif k != LOOP_STREAM and _loop_flat[k] == null:
			_loop_flat[k] = AudioStreamPlayer.new()
			_loop_flat[k].bus = bus_name
			add_child(_loop_flat[k])


func warm() -> int:
	"""The boot prewarm's step (demo_prewarm.gd): load every stream now, hand the loops theirs. Returns how many
	streams were loaded (0 while no files are staged)."""
	var loaded: int = table.load_streams()
	taps.build_ground()
	for k: int in LOOP_IDS.size():
		if _loop_row[k] < 0:
			continue
		var stream: AudioStream = table.stream_of(_loop_row[k], 0)
		if _loop_flat[k] != null:
			_loop_flat[k].stream = stream
		elif k == LOOP_STREAM and _loop_placed != null:
			_loop_placed.stream = stream
	return loaded


func bind(camera: DemoCameraScript, clock: GameManagerScript, view_on: Callable) -> void:
	"""Follow this camera, this clock's pause and `view_on() -> bool` (the U view)."""
	_camera = camera
	_clock = clock
	_view_on = view_on


func follow_demo(cast: DemoCastScript, forestry: ForestryScript, network: GraphScript, waterplay: WaterplayScript,
		services: ServicesScript, water_map: WaterMapScript) -> void:
	"""Point the event map at the village's models (any may be null: that source stays quiet) and take their
	state now as the baseline."""
	taps.brains.clear()
	if cast != null:
		for i: int in cast.actor_count():
			taps.brains.append((cast.actor(i) as DemoActorScript).brain)
	taps.swim = waterplay.state if waterplay != null else null
	taps.bridges = waterplay.bridges if waterplay != null else null
	taps.jobs = forestry.crew.jobs if forestry != null else null
	taps.skills = forestry.crew.skills if forestry != null else null
	taps.stand = forestry.stand if forestry != null else null
	taps.network = network
	taps.notices = services.notices if services != null else null
	taps.incidents = services.incidents if services != null else null
	taps.weather = services.weather if services != null else null
	taps.water_map = water_map
	taps.watch()


func follow_fishery(fishery: RefCounted) -> void:
	"""Water part B's fishery too (sound_taps.gd `fishery`): its splashes and its boats' oars."""
	taps.fishery = fishery


func is_silent() -> bool:
	"""Whether no cue has a stream loaded (no file staged: tools/stage_demo_audio.py)."""
	for r: int in table.count():
		if not table.is_silent(r):
			return false
	return true


func _ready() -> void:
	"""The listener is the scene's ear from now on."""
	listener.make_current()


func _exit_tree() -> void:
	"""Leaving the tree (a Restart, or the quit): stop every voice and loop, so no playback is left running in the
	audio server once its player is freed (the headless quit's "resources still in use")."""
	silence()


func silence() -> int:
	"""Stop the one-shot voices and the ambience loops now, their levels back to 0 (they ease in again from silence
	if the owner is used again). Returns how many players were still playing."""
	var stopped: int = voices.silence()
	for k: int in LOOP_IDS.size():
		_loop_level[k] = 0.0
		var player: Node = _loop_placed if k == LOOP_STREAM else _loop_flat[k]
		if player == null:
			continue
		if bool(player.get(&"playing")):
			stopped += 1
		player.call(&"stop")
	return stopped


func _process(delta: float) -> void:
	"""One frame of sound (see EACH FRAME), timed."""
	var started: int = Time.get_ticks_usec()
	update(Time.get_ticks_msec(), delta)
	frame_usec = Time.get_ticks_usec() - started


func update(now_msec: int, delta_s: float) -> void:
	"""Follow the camera, the pause and the U view; play this frame's events; ease the loops."""
	if _camera != null:
		set_listener(_camera.focus(), _camera.distance(), deg_to_rad(_camera.yaw_degrees()))
	if _clock != null:
		set_paused(_clock.get_effective_speed() == 0)
	if _view_on.is_valid():
		set_underground(bool(_view_on.call()))
	var events: int = taps.poll(now_msec, _listener_ground)
	for k: int in events:
		cue(taps.event_row[k], taps.event_at[k], taps.event_below[k] == 1, now_msec)
	_ease_loops(delta_s)


func set_listener(focus: Vector3, distance: float, yaw: float = 0.0) -> void:
	"""Stand the listener over `focus`, LISTENER_LIFT of `distance` up, facing the camera's heading `yaw` (radians,
	0 looking toward -Z, as demo_camera.gd's rig turns) (see THE LISTENER)."""
	_listener_at.x = focus.x
	_listener_at.y = focus.y + distance * LISTENER_LIFT
	_listener_at.z = focus.z
	_listener_ground.x = focus.x
	_listener_ground.y = focus.z
	listener.position = _listener_at
	listener.rotation.y = yaw


func listener_at() -> Vector3:
	"""Where the listener stands."""
	return _listener_at


func set_paused(on: bool) -> void:
	"""The clock stopped or started: duck the ambience, stop the world's one-shots (see PAUSED)."""
	if on == mix.paused:
		return
	mix.paused = on
	mix.apply()
	if on:
		voices.stop_bus(SoundMix.BUS_WORK, Time.get_ticks_msec())
		voices.stop_bus(SoundMix.BUS_WATER, Time.get_ticks_msec())


func set_underground(on: bool) -> void:
	"""The U view on or off: switch the underground filter (sound_mix.gd)."""
	if on == mix.underground:
		return
	mix.underground = on
	mix.apply()


func cue(row: int, at: Vector3, below: bool, now_msec: int) -> int:
	"""Offer cue `row` at `at` to the voices. Returns VoicesScript.PLAYED or why not (a REFUSE_* of this
	script's or the voices')."""
	if row < 0 or row >= table.count():
		return REFUSE_NO_CUE
	var bus: int = table.bus[row]
	if mix.paused and (bus == SoundMix.BUS_WORK or bus == SoundMix.BUS_WATER):
		return REFUSE_PAUSED
	if table.positional[row] == 1 and at.distance_to(_listener_at) > table.range_m[row]:
		return REFUSE_FAR
	return voices.play(row, at, below, now_msec)


func _ease_loops(delta_s: float) -> void:
	"""Move each loop's level towards the map's, and set its player's volume (or stop it at 0)."""
	_loop_target[LOOP_WIND] = taps.wind_permille
	_loop_target[LOOP_RAIN] = taps.rain_permille
	_loop_target[LOOP_STREAM] = taps.stream_permille
	if _loop_placed != null:
		_loop_placed.position = taps.stream_at
	var step: float = FADE_PERMILLE_PER_S * maxf(delta_s, 0.0)
	for k: int in LOOP_IDS.size():
		if _loop_row[k] < 0:
			continue
		_loop_level[k] = move_toward(_loop_level[k], float(_loop_target[k]), step)
		_set_loop_volume(k)


func _set_loop_volume(k: int) -> void:
	"""Loop `k` at its level: its table volume scaled by the level, playing while above 0 and streamed."""
	var level: float = _loop_level[k] / 1000.0
	var db: float = table.volume_db[_loop_row[k]] + (linear_to_db(level) if level > 0.0 else SoundMix.SILENT_DB)
	var flat: AudioStreamPlayer = _loop_flat[k]
	if flat != null:
		flat.volume_db = db
		_run(flat.stream != null and level > 0.0, flat.playing, flat.play, flat.stop, flat.is_inside_tree())
	elif _loop_placed != null:
		_loop_placed.volume_db = db
		_run(_loop_placed.stream != null and level > 0.0, _loop_placed.playing, _loop_placed.play,
			_loop_placed.stop, _loop_placed.is_inside_tree())


static func _run(wanted: bool, playing: bool, play: Callable, stop: Callable, in_tree: bool) -> void:
	"""Start or stop a loop's player to match `wanted` (only in the tree)."""
	if not in_tree or wanted == playing:
		return
	if wanted:
		play.call()
	else:
		stop.call()


func loop_level(k: int) -> float:
	"""Loop LOOP_* `k`'s level now, per mille (checks)."""
	return _loop_level[k]


# --- UI clicks -------------------------------------------------------------------------------------

func watch_buttons(root: Node) -> int:
	"""Click on every button under `root` now, and on every button added to the tree from now on. Returns how
	many were hooked now."""
	var hooked: int = _hook_tree(root)
	if is_inside_tree() and not get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.connect(_on_node_added)
	return hooked


func _hook_tree(node: Node) -> int:
	"""Hook `node` and everything under it."""
	var hooked: int = 1 if _hook(node) else 0
	for child: Node in node.get_children():
		hooked += _hook_tree(child)
	return hooked


func _hook(node: Node) -> bool:
	"""A button sounds the click when pressed (once hooked; hooking again changes nothing)."""
	var button := node as BaseButton
	if button == null or button.pressed.is_connected(_on_click):
		return false
	button.pressed.connect(_on_click)
	return true


func _on_node_added(node: Node) -> void:
	"""A node joined the tree: hook it if it is a button."""
	_hook(node)


func _on_click() -> void:
	"""A button was pressed."""
	cue(_click_row, Vector3.ZERO, false, Time.get_ticks_msec())
