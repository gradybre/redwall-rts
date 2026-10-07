extends SceneTree
## The livelier weather on the REAL scene (decision 1632; feature #34): each §5.10 event held in turn and drawn -- a
## storm with its lightning and a struck tree's smoulder, a drought's parched grass, an early frost's rime, a hard
## freeze's hoar frost, blight, calm days and an ideal spell. Checks the storm's work factor on the village's work pace
## (x0.80 outdoors, once), the storm's notice, and that no lightning target is a building. Not discovered by the runner.
##
##     godot --path godot --script res://test/live/demo_weather_live.gd -- --size 1920x1080 --capture <dir>
##
## (--capture needs a window: not headless.) Prints `LIVE <name>: PASS|FAIL <detail>` and `LIVE-SUMMARY <checks>
## <failures>`; exits 1 on a failure.

const WeatherCore := preload("res://scripts/core/weather.gd")

const BOOT_FRAMES: int = 20
const STEP_FRAMES: int = 6
## The lightning's flash at its first stroke's peak (lightning_fx.gd STROKES), and a fire's time to full flame (s).
const PEAK_S: float = 0.03
const FIRE_GROW_S: float = 2.8
## The look's easing (weather_view.gd EASE_S, the day's light) is on demo time: each event runs this many frames at 4x
## before its frame, then is held again (an hour crossed in between would re-read the real row).
const SETTLE_FRAMES: int = 50
const CalendarScript := preload("res://demo/demo_calendar.gd")

var _village: Node = null
var _wait: int = BOOT_FRAMES
var _steps: Array[Callable] = []
var _checks: int = 0
var _failures: int = 0
var _size: Vector2i = Vector2i(1920, 1080)
var _capture_dir: String = ""
var _pending_capture: String = ""
## The event held now (season, day, hour, tenths, rain, event): `_settle` holds it again after running.
var _held: Array = []


func _initialize() -> void:
	"""Read the arguments, size the window, boot the village and list the steps."""
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for k: int in args.size():
		if args[k] == "--size" and k + 1 < args.size():
			var parts: PackedStringArray = args[k + 1].split("x")
			_size = Vector2i(int(parts[0]), int(parts[1]))
		elif args[k] == "--capture" and k + 1 < args.size():
			_capture_dir = args[k + 1]
	root.size = _size
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_size(_size)
	_village = (load("res://demo/demo_village.tscn") as PackedScene).instantiate()
	root.add_child(_village)
	current_scene = _village
	_steps = [_pause, _to_noon, _the_storm_factor_is_on_the_pace, _a_storm, _settle, _the_storm_notice, _lightning_strikes,
		_a_tree_smoulders, _targets_avoid_buildings, _a_drought, _settle, _the_drought_frame, _an_early_frost, _settle,
		_the_early_frost_frame, _a_hard_freeze, _settle, _the_hard_freeze_frame, _blight, _settle, _the_blight_frame,
		_calm_days, _settle, _the_calm_frame, _an_ideal_spell, _settle, _the_ideal_spell_frame]
	_held = []


func _process(_delta: float) -> bool:
	"""One step each time the wait runs out; quit after the last."""
	if root.size != _size:
		root.size = _size
	_wait -= 1
	if _wait > 0:
		return false
	if not _pending_capture.is_empty():
		_save_capture()
	if _steps.is_empty():
		print("LIVE-SUMMARY %d %d" % [_checks, _failures])
		quit(1 if _failures > 0 else 0)
		return false
	var step: Callable = _steps.pop_front()
	_wait = STEP_FRAMES
	step.call()
	return false


func _check(check_name: String, ok: bool, detail: String = "") -> void:
	"""Record one check."""
	_checks += 1
	if not ok:
		_failures += 1
	print("LIVE %s: %s %s" % [check_name, "PASS" if ok else "FAIL", detail])


func _capture(file_name: String) -> void:
	"""Save this state's frame at the next step (only with --capture, never headless)."""
	if not _capture_dir.is_empty() and DisplayServer.get_name() != "headless":
		_pending_capture = file_name


func _save_capture() -> void:
	"""Write the pending frame, and forgive the clock the read-back's time."""
	root.get_texture().get_image().save_png(_capture_dir.path_join("%s_%dx%d.png" % [_pending_capture, _size.x, _size.y]))
	_pending_capture = ""
	root.get_node(^"GameManager").set("_last_host_usec", Time.get_ticks_usec())


func _services() -> Object:
	"""The village's shared services."""
	return _village.get("_services")


func _fx() -> Node3D:
	"""The livelier weather's node."""
	return _village.get("_weather_fx") as Node3D


func _view() -> Node3D:
	"""The weather's view (tunnel_ext.gd holds it)."""
	return _village.get("_command").call(&"tunnels").get("ext").get("weather_view") as Node3D


func _hold(season: int, day: int, hour: int, tenths: int, rain: int, event: int) -> void:
	"""Hold this hour's weather (paused, the calendar does not move it) and draw its look at once."""
	_held = [season, day, hour, tenths, rain, event]
	_services().get("weather").call(&"observe", season, day, hour, tenths, rain, event)
	_view().call(&"_apply_targets", 1.0)


func _to_noon() -> void:
	"""The calendar on from the opening's 06:00 to noon (the farm's own advance), so the frames are in daylight."""
	_village.get("_farm").call(&"advance_calendar", CalendarScript.HOUR_USEC * 6)


func _settle() -> void:
	"""Run SETTLE_FRAMES at 4x (the rain falls, the light and the look ease in), then pause and hold the event again."""
	var gm: Node = root.get_node(^"GameManager")
	gm.call(&"resume_game")
	gm.call(&"set_speed", 4)
	_wait = SETTLE_FRAMES
	_steps.push_front(_re_hold)


func _re_hold() -> void:
	"""Pause, at 1x again, and hold the event (see `_settle`)."""
	var gm: Node = root.get_node(^"GameManager")
	gm.call(&"pause_game")
	gm.call(&"set_speed", 1)
	_hold(_held[0], _held[1], _held[2], _held[3], _held[4], _held[5])


func _aim(at: Vector3, yaw_deg: float, pitch_deg: float, metres: float) -> void:
	"""Look at `at` from this heading, pitch and distance, at once."""
	var camera: Node = _village.get("_camera")
	camera.call(&"aim", at, yaw_deg, pitch_deg, metres)
	camera.call(&"snap")


func _village_view(file_name: String) -> void:
	"""The village from the usual height, captured."""
	_aim(Vector3(-2.0, 0.0, 4.0), 15.0, 38.0, 26.0)
	_capture(file_name)


func _pause() -> void:
	"""Pause as the player: the held weather stays."""
	root.get_node(^"GameManager").call(&"pause_game")
	_check("the livelier weather is built", _fx() != null, "")


func _the_storm_factor_is_on_the_pace() -> void:
	"""The village's work pace carries the storm factor, by name, once."""
	var pace: Object = _services().get("work_pace")
	var names := PackedStringArray()
	for k: int in int(pace.call(&"count")):
		names.append(String(pace.call(&"name_of", k)))
	_check("the work pace has the storm factor once", names.count("storm") == 1, ", ".join(names))


func _a_storm() -> void:
	"""A spring storm day at noon, raining: driven rain, a dark sky; an outdoor resident works at 80%."""
	_hold(0, 6, 12, 90, 3200, WeatherCore.EVENT_HEAVY_RAIN)
	_check("the rain is driven", float(_view().call(&"rain_slant")) > 0.1, str(_view().call(&"rain_slant")))
	var pace: Object = _fx().get("pace")
	var outdoors: int = -1
	for who: int in 9:
		if bool(pace.call(&"is_outdoors", who)):
			outdoors = who
			break
	_check("an outdoor resident is slowed to 80%", outdoors >= 0 and int(_services().get("work_pace").call(&"permille",
		outdoors)) <= 800, "resident %d" % outdoors)


func _the_storm_notice() -> void:
	"""The village was told the storm has come, with its effects."""
	var notices: Object = _services().get("notices")
	var found: String = ""
	for k: int in int(notices.call(&"count")):
		if String(notices.call(&"text", k)).begins_with("A storm has come"):
			found = String(notices.call(&"text", k))
	_check("the storm's notice", not found.is_empty(), found)
	var cast: Node = _village.get("_cast")
	var pace: Object = _fx().get("pace")
	var slowed: String = ""
	for who: int in int(cast.call(&"actor_count")):
		var brain: Object = cast.call(&"actor", who).get("brain")
		if bool(pace.call(&"is_outdoors", who)) and int(brain.get("work_permille")) <= 800:
			slowed = "%s at %d" % [str(who), int(brain.get("work_permille"))]
	_check("a resident outdoors works at 80% after the storm's frames", not slowed.is_empty(), slowed)
	_village_view("weather_storm")


func _nearest_target(to: Vector3, trees_only: bool) -> int:
	"""The lightning target nearest `to` (a tree's, with `trees_only`)."""
	var fx: Node3D = _fx()
	var best: int = -1
	for j: int in int(fx.call(&"target_count")):
		var at: Vector3 = fx.call(&"target", j)
		if (bool(fx.call(&"is_tree", j)) or not trees_only) and (best < 0 or at.distance_to(to) <
				(fx.call(&"target", best) as Vector3).distance_to(to)):
			best = j
	return best


func _lightning_strikes() -> void:
	"""A strike near the view (the automatic one lands within STRIKE_REACH_M of the focus), held at its first stroke's
	peak; for the frame, the target nearest the view's middle."""
	var fx: Node3D = _fx()
	fx.get("lightning").set("_since_s", 10.0)
	var j: int = int(fx.call(&"strike_near", fx.call(&"view_focus")))
	_check("lightning strikes near the view", j >= 0, "target %d" % j)
	fx.get("lightning").set("_since_s", 10.0)
	var near: int = _nearest_target(fx.call(&"view_focus") + Vector3(0.0, 0.0, -4.0), false)
	_check("lightning strikes open ground", bool(fx.call(&"strike", near)), str(fx.call(&"target", near)))
	var bolt: Node3D = fx.get("lightning")
	bolt.call(&"set_speed", 1.0)
	bolt.call(&"_process", PEAK_S)
	bolt.call(&"set_speed", 0.0)
	_check("the flash is up", float(bolt.call(&"flash")) > 0.9, str(bolt.call(&"flash")))
	_capture("weather_lightning")


func _a_tree_smoulders() -> void:
	"""A strike on the tree nearest the village's north edge; the village runs at 1x while its smoulder catches."""
	var fx: Node3D = _fx()
	var tree: int = _nearest_target(Vector3(4.0, 0.0, -18.0), true)
	fx.get("lightning").set("_since_s", 10.0)
	_check("a tree struck", tree >= 0 and bool(fx.call(&"strike", tree)), str(fx.call(&"target", tree)))
	root.get_node(^"GameManager").call(&"resume_game")
	_wait = int(FIRE_GROW_S * 60.0) + 20
	_steps.push_front(_the_smoulder_frame)


func _the_smoulder_frame() -> void:
	"""Paused with the smoulder burning, the storm held again; the struck tree's foot from above."""
	root.get_node(^"GameManager").call(&"pause_game")
	_hold(_held[0], _held[1], _held[2], _held[3], _held[4], _held[5])
	var fire: Node3D = _fx().call(&"pooled_fire", 0)
	_check("it smoulders", not bool(fire.call(&"is_idle")), "stage %d" % int(fire.call(&"stage")))
	_aim(fire.global_position + Vector3(0.0, 0.6, 0.0), 20.0, 30.0, 12.0)
	_capture("weather_smoulder")


func _targets_avoid_buildings() -> void:
	"""No open-ground target lies within BUILDING_CLEAR_M of a building."""
	var fx: Node3D = _fx()
	var buildings: Array[Vector3] = _village.get("_world").call(&"building_obstacles")
	var bad: int = 0
	for j: int in int(fx.call(&"target_count")):
		var at: Vector3 = fx.call(&"target", j)
		for c: Vector3 in buildings:
			if not bool(fx.call(&"is_tree", j)) and Vector2(at.x - c.x, at.z - c.z).length() < c.y + 6.0:
				bad += 1
	_check("no target at a building", bad == 0, "%d targets" % int(fx.call(&"target_count")))


func _a_drought() -> void:
	"""A summer drought at noon: the grass parched, a heat haze."""
	_hold(1, 7, 12, 300, 0, WeatherCore.EVENT_DROUGHT)
	_check("the grass is parched", float(_view().call(&"dryness")) > 0.99, str(_view().call(&"dryness")))


func _the_drought_frame() -> void:
	"""The drought, eased in."""
	_village_view("weather_drought")


func _an_early_frost() -> void:
	"""An autumn early frost's morning: a rime lying."""
	_hold(2, 10, 9, -30, 0, WeatherCore.EVENT_EARLY_FROST)
	_check("a rime lies", float(_view().call(&"cover")) > 0.3, str(_view().call(&"cover")))


func _the_early_frost_frame() -> void:
	"""The early frost, eased in."""
	_village_view("weather_early_frost")


func _a_hard_freeze() -> void:
	"""A winter hard freeze at noon: a heavy hoar frost, mist, a low cold sun."""
	_hold(3, 7, 12, -170, 0, WeatherCore.EVENT_HARD_FREEZE)
	_check("a hoar frost lies", float(_view().call(&"cover")) > 0.85, str(_view().call(&"cover")))


func _the_hard_freeze_frame() -> void:
	"""The hard freeze, eased in."""
	_village_view("weather_hard_freeze")


func _blight() -> void:
	"""Summer blight: the look is the farm's beds' own."""
	_hold(1, 7, 12, 220, 0, WeatherCore.EVENT_BLIGHT)


func _the_blight_frame() -> void:
	"""Blight, eased in."""
	_village_view("weather_blight")


func _calm_days() -> void:
	"""Calm days: no change."""
	_hold(0, 7, 12, 120, 0, WeatherCore.EVENT_CALM_DAYS)
	_check("calm days change nothing", float(_view().call(&"cover")) < 0.01 and float(_view().call(&"dryness")) < 0.01, "")


func _the_calm_frame() -> void:
	"""Calm days, eased in."""
	_village_view("weather_calm")


func _an_ideal_spell() -> void:
	"""The first spring's ideal spell: a little brighter."""
	_hold(0, 6, 12, 180, 1800, WeatherCore.EVENT_IDEAL_SPELL)


func _the_ideal_spell_frame() -> void:
	"""The ideal spell, eased in."""
	_village_view("weather_ideal_spell")
