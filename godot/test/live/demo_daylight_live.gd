extends SceneTree
## The live demo's DAY AND NIGHT on the REAL scene (decision 0541). Not discovered by the runner (it is not `test_*.gd`
## in test/): test/test_demo_daylight_live.gd runs it in its own process, as the other live harnesses run (decision
## 0261).
##
##     godot --headless --path godot --script res://test/live/demo_daylight_live.gd [-- --size 1920x1080]
##         [-- --capture <dir>]   (not headless: saves the checked frames as PNGs, from one fixed camera)
##         [-- --measure]         (not headless: frame times at noon and midnight with the night lights' pool full,
##                                 the first dusk run through at 4x, and the U view switched at night)
##
## It boots demo/demo_village.tscn (on placeholders when the assets are not staged) and runs the calendar on through
## one spring day and the next, from the one camera: 06:00, 12:00, 19:30, 23:00 (a resident selected and ordered along
## the square's path), 04:30, a rainy dusk (spring 2 is a spell's wet day: rain 06:00-23:59), a snowy night and the
## underground at night. At each it checks what the light is -- the sun or the moon, the shadow on or off, the lamps,
## the date trigger's icon -- and that the U view keeps its own environment and the surface's light never reaches it;
## then it turns Brighter nights on in the Settings and checks the night rose. Prints `LIVE <name>: PASS|FAIL <detail>`
## per check and `LIVE-SUMMARY <checks> <failures>`; with --measure, `MEASURE <name> <values>` lines too. Exits 1 on
## any failure.

const SimClock := preload("res://scripts/core/sim_clock.gd")
const CalendarScript := preload("res://demo/demo_calendar.gd")
const Access := preload("res://demo/access/demo_access.gd")
const Daylight := preload("res://demo/world/daylight.gd")
const Curves := preload("res://demo/world/daylight_curves.gd")
const HearthFuel := preload("res://demo/winter/hearth_fuel.gd")
const Layers := preload("res://demo/demo_layers.gd")
const WeatherScript := preload("res://demo/weather/demo_weather.gd")

const BOOT_FRAMES: int = 12
const STEP_FRAMES: int = 2
## Frames a jump settles for before it is checked and captured (the sky's radiance is redrawn over several).
const SETTLE_FRAMES: int = 24
const RUN_MSEC: int = 40000
## The one camera every frame is taken from: its focus on the square, its default distance and pitch.
const FOCUS: Vector3 = Vector3(-1.5, 0.0, -3.5)
## Frames measured at each of noon and midnight.
const MEASURE_FRAMES: int = 300
## The resident ordered along the square's path at 23:00, and where to.
const WALK_TO: Vector3 = Vector3(0.3, 0.0, -5.2)

var _village: Node = null
var _wait: int = BOOT_FRAMES
var _steps: Array[Callable] = []
var _checks: int = 0
var _failures: int = 0
var _size: Vector2i = Vector2i(1920, 1080)
var _capture_dir: String = ""
var _measure: bool = false
var _pending_capture: String = ""
var _waiting: Callable = Callable()
var _deadline_msec: int = 0
## Frame timing (measure): real microseconds of each frame, and the last frame's stamp.
var _frame_usec: PackedInt64Array = PackedInt64Array()
var _last_usec: int = 0
var _timing: bool = false
var _gpu_ms: PackedFloat64Array = PackedFloat64Array()
var _walker: int = -1
var _dusk_label: String = "dusk_4x_first"


func _initialize() -> void:
	"""Read the arguments, size the window, boot the village and list the steps."""
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for k: int in args.size():
		if args[k] == "--size" and k + 1 < args.size():
			var parts: PackedStringArray = args[k + 1].split("x")
			_size = Vector2i(int(parts[0]), int(parts[1]))
		elif args[k] == "--capture" and k + 1 < args.size():
			_capture_dir = args[k + 1]
		elif args[k] == "--measure":
			_measure = DisplayServer.get_name() != "headless"
	root.size = _size
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_size(_size)
		if _measure:
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
			RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	_village = (load("res://demo/demo_village.tscn") as PackedScene).instantiate()
	root.add_child(_village)
	current_scene = _village
	_steps = [_wait_until_open]
	if _measure:
		_steps.append_array([_sunrise_begin, _sunrise_wait, _sunrise_check, _fix_the_camera, _to_before_first_dusk,
			_run_through_dusk_begin, _run_through_dusk_wait, _run_through_dusk_end, _to_midnight_full, _measure_wait, _measure_midnight_end, _to_next_noon,
			_measure_noon_begin, _measure_wait, _measure_noon_end, _to_day_run, _run_day_begin, _run_day_wait,
			_run_day_end, _to_next_late, _underground_on, _measure_wait, _check_underground, _underground_off,
			_dusk_again.bind(2, true), _run_through_dusk_begin, _run_through_dusk_wait, _run_through_dusk_end,
			_dusk_again.bind(3, false), _run_through_dusk_begin, _run_through_dusk_wait, _run_through_dusk_end])
		return
	_steps.append_array([_fix_the_camera, _at_dawn, _check_dawn, _sunrise_begin, _sunrise_wait, _sunrise_check, _to_noon,
		_check_noon, _to_dusk, _check_dusk, _to_late, _order_a_walker, _check_late, _walker_on_the_path, _to_before_dawn, _check_before_dawn, _to_rainy_dusk, _check_rainy_dusk,
		_to_snowy_night, _snow_settles, _check_snowy_night, _underground_on, _check_underground, _underground_off,
		_brighter_nights_on, _check_brighter_nights, _brighter_nights_off])


func _process(_delta: float) -> bool:
	"""One step each time the wait runs out (a waiting step is asked again each frame); quit after the last."""
	if root.size != _size:
		root.size = _size
	_time_frame()
	if _waiting.is_valid():
		if not bool(_waiting.call(Time.get_ticks_msec() >= _deadline_msec)):
			return false
		_waiting = Callable()
		_wait = STEP_FRAMES
	_wait -= 1
	if _wait > 0:
		return false
	if not _pending_capture.is_empty():
		_save_capture()
	if _steps.is_empty():
		Access.reset()
		print("LIVE-SUMMARY %d %d" % [_checks, _failures])
		quit(1 if _failures > 0 else 0)
		return false
	var step: Callable = _steps.pop_front()
	step.call()
	if _wait < STEP_FRAMES:
		_wait = STEP_FRAMES
	return false


# --- helpers ----------------------------------------------------------------------------------------------------

func _check(check_name: String, ok: bool, detail: String = "") -> void:
	"""Record one check."""
	_checks += 1
	if not ok:
		_failures += 1
	print("LIVE %s: %s %s" % [check_name, "PASS" if ok else "FAIL", detail])


func _key(code: Key) -> void:
	"""Press and release one key through the Viewport."""
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		root.push_input(event)


func _capture(file_name: String) -> void:
	"""Save this state's frame at the next step (only when asked for, and never headless)."""
	if not _capture_dir.is_empty() and DisplayServer.get_name() != "headless":
		_pending_capture = file_name


func _save_capture() -> void:
	"""Write the pending frame, and forgive the clock the time the read-back took."""
	root.get_texture().get_image().save_png(_capture_dir.path_join("%s_%dx%d.png" % [_pending_capture, _size.x, _size.y]))
	_pending_capture = ""
	_forgive()


func _forgive() -> void:
	"""Tell the game clock no real time passed during a slow harness frame (no overload pause from the harness)."""
	root.get_node(^"GameManager").set("_last_host_usec", Time.get_ticks_usec())


func _manager() -> Object:
	"""The GameManager autoload."""
	return root.get_node(^"GameManager")


func _calendar() -> CalendarScript:
	"""The demo calendar."""
	return _village.call(&"services").get("calendar")


func _day_night() -> Node:
	"""The lighting cycle."""
	return _village.call(&"day_night")


func _lights() -> Node3D:
	"""The surface's night lights."""
	return _village.call(&"night_lights")


func _sample() -> Daylight.Sample:
	"""The cycle's last sample."""
	return _day_night().get("sample")


func _sun() -> DirectionalLight3D:
	"""The world's one light."""
	return _day_night().call(&"sun")


func _env() -> Environment:
	"""The surface's environment."""
	return _day_night().call(&"environment")


func _tunnel_view() -> Node3D:
	"""The underground view."""
	return _village.get("_command").call(&"tunnels").get("view")


func _weather_view() -> Node3D:
	"""The weather's view."""
	return _village.get("_command").call(&"tunnels").get("ext").get("weather_view")


func _command() -> Node:
	"""The command layer."""
	return _village.get("_command")


func _pause(held: bool) -> void:
	"""Pause (`held`) or resume as the player (Space), when not already so."""
	if bool(_manager().call(&"is_paused")) != held:
		_key(KEY_SPACE)


func _jump_to(day: int, hour: int, minute: int) -> void:
	"""Run the calendar on (never back) to `minute` past `hour` on day `day` (0: the first), as the Lab's Next weather
	does; the light is written at once, then settles SETTLE_FRAMES frames."""
	@warning_ignore("integer_division")
	var to: int = day * SimClock.TICKS_PER_DAY + (hour - 6) * SimClock.TICKS_PER_HOUR + minute * SimClock.TICKS_PER_HOUR / 60
	var usec: int = CalendarScript.usec_for_ticks(maxi(to - _calendar().tick, 0))
	if usec > 0:
		_village.get("_farm").call(&"advance_calendar", usec)
	_day_night().call(&"update")
	_forgive()
	_wait = SETTLE_FRAMES


func _icon_is_day() -> bool:
	"""Whether the date trigger wears the sun."""
	var shell: Node = _village.call(&"_shell")
	var date: Button = shell.call(&"status_label")
	return date.icon == _day_night().call(&"day_icon")


func _hhmm() -> String:
	"""The calendar's time, HH:MM."""
	var at := SimClock.Calendar.new(_calendar().tick)
	return "%02d:%02d" % [at.hour, at.minute]


# --- the day ----------------------------------------------------------------------------------------------------

func _wait_until_open() -> void:
	"""Wait for the boot's prewarm to release the clock."""
	_waiting = func(late: bool) -> bool: return late or bool(_village.call(&"time_control").get("opened"))
	_deadline_msec = Time.get_ticks_msec() + RUN_MSEC


func _sunrise_begin() -> void:
	"""The boot's own sunrise at 1x, untouched: the light is first shadowed a few seconds in (decision 0541's day
	prewarm drew those pipelines). Time every frame until 06:06."""
	_check("the village opened at sunrise", _sample().minute < 362.0, "%.1f" % _sample().minute)
	_frame_usec.clear()
	_gpu_ms.clear()
	_timing = true
	_pause(false)


func _sunrise_wait() -> void:
	"""Until 06:06 (about 2.5 real seconds at 1x)."""
	_waiting = func(late: bool) -> bool: return late or Daylight.minute_of_tick(_calendar().tick) >= 366.0
	_deadline_msec = Time.get_ticks_msec() + RUN_MSEC


func _sunrise_check() -> void:
	"""The shadow came on with no stall pause."""
	_timing = false
	_check("06:06: the sun's shadow on", _sun().shadow_enabled, _hhmm())
	_check("the sunrise ran with no stall pause", not bool(_manager().call(&"is_paused")),
		str(_manager().call(&"get_pause_reason_names")))
	_pause(true)
	if _measure:
		_report("sunrise_1x", _frame_usec)


func _fix_the_camera() -> void:
	"""The one camera: on the square at the default distance and pitch; paused, so nothing moves between frames."""
	var camera: Node = _village.get("_camera")
	camera.call(&"reset_view")
	camera.call(&"centre_on", FOCUS)
	camera.call(&"snap")
	_pause(true)
	_village.call(&"guide").call(&"skip")
	if not _capture_dir.is_empty():
		(_village.call(&"pause_card") as CanvasLayer).visible = false
	_check("the prewarm drew the night", int(_day_night().get("applies")) >= 3, str(_day_night().get("applies")))
	_wait = SETTLE_FRAMES


func _at_dawn() -> void:
	"""06:00 on spring 1: the demo opens at sunrise, the middle of the dawn."""
	_jump_to(0, 6, 0)


func _check_dawn() -> void:
	"""Sunrise: the dawn's own light, from the east, the lamps half lit."""
	var sample := _sample()
	_check("06:00 is the dawn", sample.phase == Daylight.PHASE_DAWN, "%s phase %d" % [_hhmm(), sample.phase])
	_check("06:00's light from the east", sample.light_toward.x > 0.5, str(sample.light_toward))
	_check("06:00's date shows the sun", _icon_is_day())
	_check("06:00's lamps half lit", is_equal_approx(_lights().call(&"level"), 0.5), str(_lights().call(&"level")))
	_capture("01_0600")


func _to_noon() -> void:
	"""12:00."""
	_jump_to(0, 12, 0)


func _check_noon() -> void:
	"""Noon: the world's own day look, the sun high in the south, its shadow on, the lamps out, a sun on the date."""
	var sun := _sun()
	_check("12:00 is the day", _sample().phase == Daylight.PHASE_DAY, _hhmm())
	_check("12:00's sun the world's", is_equal_approx(sun.light_energy, Curves.LIGHT_ENERGY[Curves.KEY_DAY])
		and sun.light_color.is_equal_approx(Curves.LIGHT_COLOUR[Curves.KEY_DAY]), "%s %s" % [sun.light_energy, sun.light_color])
	_check("12:00's sun in the south, high", _sample().light_toward.z > 0.4 and _sample().light_toward.y > 0.75,
		str(_sample().light_toward))
	_check("12:00's shadow on", sun.shadow_enabled and is_equal_approx(sun.shadow_opacity, 1.0))
	_check("12:00's lamps out", _lights().call(&"lit_count") == 0 and not _env().glow_enabled)
	_check("12:00's date shows the sun", _icon_is_day())
	_capture("02_1200")


func _to_dusk() -> void:
	"""19:30: early dusk."""
	_jump_to(0, 19, 30)


func _check_dusk() -> void:
	"""Half past seven: a warm low light from the west, dimming; the lamps coming on."""
	var sample := _sample()
	_check("19:30 is the dusk", sample.phase == Daylight.PHASE_DUSK, _hhmm())
	_check("19:30's light from the west, low", sample.light_toward.x < -0.5, str(sample.light_toward))
	_check("19:30's lamps coming on", float(_lights().call(&"level")) > 0.0 and float(_lights().call(&"level")) < 1.0,
		str(_lights().call(&"level")))
	_capture("03_1930")


func _to_late() -> void:
	"""23:00: night. Resume for a moment so the night routine sends the village home."""
	_jump_to(0, 23, 0)


func _order_a_walker() -> void:
	"""A resident on the surface, selected and ordered along the square's path (a direct order wakes one)."""
	var cast: Node = _village.get("_cast")
	for i: int in int(cast.call(&"actor_count")):
		var actor: Node3D = cast.call(&"actor", i)
		if actor.visible and actor.global_position.y > -0.2 and actor.global_position.distance_to(FOCUS) < 14.0:
			_walker = i
			break
	_walker = maxi(_walker, 0)
	_command().call(&"select", PackedInt32Array([_walker]))
	_command().call(&"order_to", WALK_TO)
	_pause(false)
	var walker: Node3D = _village.get("_cast").call(&"actor", _walker)
	_waiting = func(late: bool) -> bool: return late or walker.global_position.distance_to(WALK_TO) < 0.6
	_deadline_msec = Time.get_ticks_msec() + RUN_MSEC


func _check_late() -> void:
	"""Deep night: the moon's light, no shadow pass, the pool lit, the glow on, a moon on the date."""
	_pause(true)
	var sun := _sun()
	_check("23:00 is the night", _sample().phase == Daylight.PHASE_NIGHT, _hhmm())
	_check("23:00's light the moon's", sun.light_color.is_equal_approx(Curves.LIGHT_COLOUR[Curves.KEY_NIGHT]),
		str(sun.light_color))
	_check("23:00's shadow pass off", not sun.shadow_enabled)
	var lit: int = _lights().call(&"lit_count")
	_check("23:00's night lights lit, within the pool", lit > 0 and lit <= Curves.NIGHT_LIGHTS, "%d lit" % lit)
	_check("23:00's glow on", _env().glow_enabled)
	_check("23:00's date shows the moon", not _icon_is_day())
	_check_home_lamps()
	_wait = SETTLE_FRAMES


func _check_home_lamps() -> void:
	"""The homes' lamplight query is bound (decision 0902): the hall's lamp is dark only while its hearth is out of fuel
	or let go out -- lit on a night that wants no heat -- and a residence, with no hearth in the winter's model, keeps
	the lamps' hours."""
	var fuel: Object = _village.call(&"winter").fuel
	var cold: bool = bool(fuel.call(&"hearth_cold", HearthFuel.HALL))
	_check("23:00's hall lamp follows its hearth", bool(_village.call(&"home_lamp_lit", 0)) == not cold,
		"hearth cold %s" % cold)
	fuel.call(&"set_banked", HearthFuel.HALL, true)
	fuel.call(&"pass_hour", int(fuel.get(&"hour_index")) + 1, int(fuel.get(&"season")), int(fuel.get(&"day_mean_tenths")),
		int(fuel.get(&"air_tenths")))
	_check("23:00's hall lamp dark with its hearth let go out", not bool(_village.call(&"home_lamp_lit", 0)))
	fuel.call(&"set_banked", HearthFuel.HALL, false)
	_check("23:00's residence lamp lit", bool(_village.call(&"home_lamp_lit", 1)))


func _walker_on_the_path() -> void:
	"""The selected resident, readable at night on the path (captured)."""
	_check("23:00: a resident is selected", int(_command().call(&"selection_count")) == 1)
	_capture("04_2300_selected")


func _to_before_dawn() -> void:
	"""04:30 on spring 2."""
	_jump_to(1, 4, 30)


func _check_before_dawn() -> void:
	"""Half past four: still night."""
	_check("04:30 is still the night", _sample().phase == Daylight.PHASE_NIGHT and not _sun().shadow_enabled, _hhmm())
	_capture("05_0430")


func _to_rainy_dusk() -> void:
	"""19:30 on spring 2, a spell's wet day: raining (resumed a little so the rain falls and the gloom eases in)."""
	_jump_to(1, 19, 30)
	_pause(false)
	_waiting = func(late: bool) -> bool: return late or float(_weather_view().call(&"gloom")) > 0.55
	_deadline_msec = Time.get_ticks_msec() + RUN_MSEC


func _check_rainy_dusk() -> void:
	"""Rain at dusk: darker and greyer than the clear dusk, the sun's share cut."""
	_pause(true)
	var weather: Node = _weather_view()
	var gloom: float = weather.call(&"gloom")
	_check("the rainy dusk is raining", bool(weather.call(&"raining")), _hhmm())
	_check("the rain's gloom eased in", gloom > 0.3, str(gloom))
	_check("the rain greys the dusk", _env().adjustment_saturation < Curves.SATURATION[Curves.KEY_DUSK],
		str(_env().adjustment_saturation))
	_wait = SETTLE_FRAMES
	_capture("06_1930_rain")


func _to_snowy_night() -> void:
	"""23:00 on spring 2, the weather made snow (a winter wet day's reading) and held: it lies and falls at night."""
	_jump_to(1, 23, 0)
	var weather: WeatherScript = _village.call(&"services").get("weather")
	weather.observe(3, 2, 23, -50, 1200, -1)
	_pause(false)


func _snow_settles() -> void:
	"""Let the cover lie and the flakes fall (the calendar does not reach midnight)."""
	_waiting = func(late: bool) -> bool: return late or float(_weather_view().call(&"cover")) > 0.95
	_deadline_msec = Time.get_ticks_msec() + RUN_MSEC


func _check_snowy_night() -> void:
	"""Snow at night: the cover lies, the flakes fall, tinted with the night."""
	_pause(true)
	var weather: Node = _weather_view()
	_check("the snowy night is snowing", bool(weather.call(&"snowing")) and float(weather.call(&"cover")) > 0.8,
		"cover %s at %s" % [weather.call(&"cover"), _hhmm()])
	_check("the night still the night", _sample().phase == Daylight.PHASE_NIGHT)
	_wait = SETTLE_FRAMES
	_capture("07_2300_snow")


func _underground_on() -> void:
	"""U at night: the camera wears the underground's own environment; timed (no stall)."""
	_frame_usec.clear()
	_gpu_ms.clear()
	_timing = _measure
	_tunnel_view().set_on(true)
	_wait = SETTLE_FRAMES


func _check_underground() -> void:
	"""The U view keeps its own look: its environment on the camera and unchanged, the surface's light culled."""
	var view := _tunnel_view()
	var camera: Camera3D = _village.get("_camera").call(&"camera")
	var fresh: Environment = view.call(&"underground_environment")
	var env: Environment = view.get("environment")
	_check("U at night: the underground's own environment", camera.environment == env)
	_check("U at night: its environment untouched", env.ambient_light_color == fresh.ambient_light_color
		and is_equal_approx(env.ambient_light_energy, fresh.ambient_light_energy)
		and env.background_color == fresh.background_color and is_equal_approx(env.fog_density, fresh.fog_density)
		and is_equal_approx(env.tonemap_exposure, fresh.tonemap_exposure)
		and is_equal_approx(env.adjustment_saturation, fresh.adjustment_saturation))
	_check("U at night: the moon lights the surface only", _sun().light_cull_mask & Layers.UNDERGROUND_VIEW == 0
		and camera.cull_mask & _sun().layers == 0, "cull %d" % _sun().light_cull_mask)
	var lamp: OmniLight3D = _lights().call(&"light", 0)
	_check("U at night: the night lights culled", camera.cull_mask & lamp.layers == 0
		and lamp.light_cull_mask & Layers.UNDERGROUND_VIEW == 0)
	if _measure:
		_timing = false
		_report("u_view_night", _frame_usec)
	_capture("08_2300_underground")


func _underground_off() -> void:
	"""Back to the surface."""
	_tunnel_view().set_on(false)
	_wait = SETTLE_FRAMES


func _brighter_nights_on() -> void:
	"""Settings: the Brighter nights toggle, pressed."""
	_check("night before: brighter nights off", not Access.is_on(Access.SET_BRIGHT_NIGHTS))
	_village.set_meta(&"ambient_before", _env().ambient_light_energy)
	_village.set_meta(&"moon_before", _sun().light_energy)
	var menu: Node = _village.call(&"menu")
	var toggle: Button = menu.get("access").call(&"toggle_button", Access.SET_BRIGHT_NIGHTS)
	toggle.button_pressed = true
	_wait = 4


func _check_brighter_nights() -> void:
	"""The night's ambient and moon rose at once."""
	var before: float = _village.get_meta(&"ambient_before")
	var moon: float = _village.get_meta(&"moon_before")
	_check("Brighter nights on", Access.is_on(Access.SET_BRIGHT_NIGHTS))
	_check("Brighter nights raised the ambient", _env().ambient_light_energy > before * 1.5,
		"%s -> %s" % [before, _env().ambient_light_energy])
	_check("Brighter nights raised the moon", _sun().light_energy > moon * 1.3, "%s -> %s" % [moon, _sun().light_energy])
	_capture("09_2300_snow_brighter")


func _brighter_nights_off() -> void:
	"""Off again."""
	var menu: Node = _village.call(&"menu")
	(menu.get("access").call(&"toggle_button", Access.SET_BRIGHT_NIGHTS) as Button).button_pressed = false


# --- measuring (not headless) ----------------------------------------------------------------------------------

func _time_frame() -> void:
	"""One frame's real time, while timing (and the viewport's GPU render time)."""
	var now := Time.get_ticks_usec()
	if _timing and _last_usec > 0:
		_frame_usec.append(now - _last_usec)
		_gpu_ms.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
	_last_usec = now


func _report(label: String, frames: PackedInt64Array) -> void:
	"""MEASURE <label>: frames, p50/p95/p99/max ms, and the mean GPU ms."""
	if frames.is_empty():
		return
	var sorted := frames.duplicate()
	sorted.sort()
	var gpu := 0.0
	for ms: float in _gpu_ms:
		gpu += ms
	var over_50 := 0
	for usec: int in sorted:
		over_50 += 1 if usec > 50000 else 0
	print("MEASURE %s frames %d p50 %.2f p95 %.2f p99 %.2f max %.2f ms over50ms %d gpu_mean %.2f ms lit %d draws %d"
		% [label, sorted.size(), _pct(sorted, 50) / 1000.0, _pct(sorted, 95) / 1000.0, _pct(sorted, 99) / 1000.0,
		float(sorted[sorted.size() - 1]) / 1000.0, over_50, gpu / maxf(float(_gpu_ms.size()), 1.0),
		int(_lights().call(&"lit_count")), int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))])
	var first := PackedStringArray()
	for k: int in mini(6, frames.size()):
		first.append("%.1f" % (float(frames[k]) / 1000.0))
	print("MEASURE %s first_frames_ms %s" % [label, ", ".join(first)])
	_gpu_ms.clear()


static func _pct(sorted: PackedInt64Array, p: int) -> float:
	"""The p-th percentile of sorted values."""
	@warning_ignore("integer_division")
	var at: int = clampi((sorted.size() - 1) * p / 100, 0, sorted.size() - 1)
	return float(sorted[at])


func _to_next_noon() -> void:
	"""12:00 of the second day (measuring)."""
	_jump_to(1, 12, 0)


func _to_day_run() -> void:
	"""The control for the dusk run: 13:00 of the second day at 4x, as long, the light hardly moving."""
	_jump_to(1, 13, 0)
	_manager().call(&"set_speed", 4)


func _run_day_begin() -> void:
	"""Run, timing every frame, until 15:30."""
	_frame_usec.clear()
	_gpu_ms.clear()
	_timing = true
	_pause(false)


func _run_day_wait() -> void:
	"""Until 15:30."""
	_waiting = func(late: bool) -> bool: return late or Daylight.minute_of_tick(_calendar().tick) >= 15.0 * 60.0 + 30.0
	_deadline_msec = Time.get_ticks_msec() + RUN_MSEC


func _run_day_end() -> void:
	"""Report the day at 4x."""
	_timing = false
	_pause(true)
	_report("day_4x", _frame_usec)


func _to_next_late() -> void:
	"""23:00 of the second day (measuring)."""
	_jump_to(1, 23, 0)


func _measure_noon_begin() -> void:
	"""Time MEASURE_FRAMES frames at noon (paused: the same frame drawn)."""
	_frame_usec.clear()
	_gpu_ms.clear()
	_timing = true


func _measure_wait() -> void:
	"""Until MEASURE_FRAMES frames are timed."""
	_waiting = func(late: bool) -> bool: return late or _frame_usec.size() >= MEASURE_FRAMES
	_deadline_msec = Time.get_ticks_msec() + RUN_MSEC


func _measure_noon_end() -> void:
	"""Report noon."""
	_timing = false
	_report("noon", _frame_usec)
	_forgive()


func _to_midnight_full() -> void:
	"""00:00 on spring 2 with the night lights' pool full: the homes and stand-in lanterns round the focus."""
	_jump_to(1, 0, 0)
	_lights().call(&"set_mouth_source", func(out: PackedVector3Array) -> int:
		for k: int in 6:
			out[k] = FOCUS + Vector3(cos(k * 1.05) * 4.0, 0.9, sin(k * 1.05) * 4.0)
		return 6)
	_lights().call(&"read_mouths")
	_lights().call(&"update", FOCUS)
	_wait = SETTLE_FRAMES
	_frame_usec.clear()
	_gpu_ms.clear()
	_timing = true


func _measure_midnight_end() -> void:
	"""Report midnight, and put the mouths' real source back."""
	_timing = false
	_report("midnight_pool_full", _frame_usec)
	_lights().call(&"set_mouth_source", _village.get("_command").call(&"tunnels").get("overlay").lantern_spots_into)
	_forgive()


func _to_before_first_dusk() -> void:
	"""The boot's FIRST dusk (the night was only drawn by the prewarm): 18:45 of the first day, at 4x, from the one
	camera -- every frame through it timed."""
	_jump_to(0, 18, 45)
	_manager().call(&"set_speed", 4)


func _dusk_again(day: int, cycle_on: bool) -> void:
	"""Another dusk at 4x, on day `day`: with the cycle running, or with it stopped (the control: the same village's
	dusk, its light held), so the cycle's own share of the frame shows."""
	_jump_to(day, 18, 45)
	_day_night().process_mode = Node.PROCESS_MODE_INHERIT if cycle_on else Node.PROCESS_MODE_DISABLED
	_dusk_label = "dusk_4x_day%d_%s" % [day, "cycle_on" if cycle_on else "cycle_off"]
	_manager().call(&"set_speed", 4)


func _run_through_dusk_begin() -> void:
	"""Run, timing every frame, until 21:15."""
	_frame_usec.clear()
	_gpu_ms.clear()
	_timing = true
	_pause(false)


func _run_through_dusk_wait() -> void:
	"""Until 21:15."""
	_waiting = func(late: bool) -> bool: return late or Daylight.minute_of_tick(_calendar().tick) >= 21.0 * 60.0 + 15.0
	_deadline_msec = Time.get_ticks_msec() + RUN_MSEC


func _run_through_dusk_end() -> void:
	"""Report the dusk at 4x."""
	_timing = false
	_pause(true)
	_report(_dusk_label, _frame_usec)
	_check("the dusk ran through to the night", Daylight.minute_of_tick(_calendar().tick) >= 21.0 * 60.0, _hhmm())
