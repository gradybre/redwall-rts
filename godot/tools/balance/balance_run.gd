extends RefCounted
## THE BALANCE HARNESS: a game year (or any number of days) of the REAL demo village, headless, at 4x, measured day by
## day. Decision 0571. Measurement only -- see HARNESS-ONLY SETTINGS for everything it sets.
##
##     godot --headless --path godot --fixed-fps 30 --script res://tools/balance/year_runner.gd -- \
##         --seed 1 --policy hands_off --days 48 --out /abs/run.json [--csv /abs/run.csv] [--hours N] [--fps 30]
##
## --policy hands_off     the default crews and the automatic work board; nobody orders anything;
##          light_touch   the scripted player of light_touch_policy.gd queues sensible work each morning.
## --days N               run to the start of calendar day N (day 0 is Spring 1; the demo opens at 06:00 on it);
##                        48 is a year. --hours N instead runs N game hours from the start (a short check).
## --seed N               the run's seed (see SEEDS). The same seed and policy give the same numbers.
##
## TIME. `--fixed-fps 30` is REQUIRED (with --fps saying the same number, 30 by default): every frame is then exactly
## 1/30 s whatever it really took, so the village runs as fast as the machine allows and the run does not depend on
## the machine's speed. At 4x a frame is 4 calendar ticks
## (133 333 demo microseconds, handed to the walkers in the clock's own 33 ms sub-steps) -- what a player at 4x on a
## 30 Hz frame sees. The runner refuses to start when the frame time is not 1/fps (a missing flag would silently make
## the run real-time and machine-dependent). The engine does not pass --fixed-fps on to scripts, so the run checks every
## frame's delta against --fps instead.
##
## HARNESS-ONLY SETTINGS (each a public setting or the player's own control; no game code is changed), applied on the
## first frame, while the demo's opening hold still pauses its clock (nothing has walked, claimed or planned yet):
##   * The routing desk's per-frame budget is 0 (demo_cast.gd `set_route_budget`, its documented "no budget": every
##     route planned at once), and the navigation rebuilds are finished inside the cast's own frame (its `window_tail`,
##     wrapped) and again at the start of every frame: both are otherwise sliced by real microseconds.
##   * The seed (see SEEDS).
##   * GameManager's processing is stopped once it is reachable -- a guard only: the settlement clock folds REAL time
##     into ticks and could step the speed down on an overload, but the demo never starts that clock today
##     (`start_game` is the game's, not the demo's), so nothing changes while that stays so.
##   * A critical incident's autopause (UI §8.1, default on) is lifted the next frame by the pause ledger's own Resume,
##     the player's Space; each one is counted.
## SEEDS. The seed re-seeds the farm's WEATHER stream (rng.gd `seed_world`, before any season's event is drawn: the
## first spring is forced) and each resident's own choices (resident_brain.gd `rng`). The demo's threat schedule and
## deadfall keep their fixed seeds.
##
## THE RUN lives here, not in the main loop's script (year_runner.gd): a main loop's script is compiled before the
## autoloads are registered, and the demo's scripts name them, so the demo can only be preloaded by a script loaded
## once the main loop has started.
##
## OUTPUT: one JSON (meta, every day, every season rolled up, the run's totals) and, with --csv, a CSV of one row a day.
## Prints `BALANCE-DAY n closed` as each day closes, `BALANCE-RUN ok ...` at the end, or `BALANCE-RUN error ...` and
## exits 2.

const TimeControlScript := preload("res://demo/session/time_control.gd")
const KitchenNodeScript := preload("res://demo/kitchen/demo_kitchen.gd")
const DemoWorkScript := preload("res://demo/work/demo_work.gd")
const BoardScript := preload("res://demo/work/work_board.gd")
const FisheryNodeScript := preload("res://demo/fishery/demo_fishery.gd")
const ServicesScript := preload("res://demo/demo_services.gd")
const WaterplayScript := preload("res://demo/waterplay/demo_waterplay.gd")
const ForestryScript := preload("res://demo/forestry/demo_forestry.gd")
const GameManagerScript := preload("res://scripts/systems/game_manager.gd")
const DemoCastScript := preload("res://demo/cast/demo_cast.gd")
const DemoFarmScript := preload("res://demo/farm/demo_farm.gd")
const DemoCommandScript := preload("res://demo/control/demo_command.gd")
const KitchenScript := preload("res://demo/kitchen/kitchen.gd")
const WorksScript := preload("res://demo/tunnel/tunnel_works.gd")
const ManifestScript := preload("res://demo/demo_manifest.gd")
const FoodScript := preload("res://tools/balance/balance_food.gd")
const LabourScript := preload("res://tools/balance/balance_labour.gd")
const FarmWatchScript := preload("res://tools/balance/balance_farm_watch.gd")
const EventsWatchScript := preload("res://tools/balance/balance_events.gd")
const PolicyScript := preload("res://tools/balance/light_touch_policy.gd")
const Rollup := preload("res://tools/balance/balance_rollup.gd")
const Csv := preload("res://tools/balance/balance_csv.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")

const POLICIES: Array[String] = ["hands_off", "light_touch"]
const FLAGS: Array[String] = ["--seed", "--policy", "--days", "--hours", "--out", "--csv", "--fps"]
const SPEED: int = 4
## The run stops with an error when the demo has not opened by this frame, or stays paused this many frames.
const OPEN_LIMIT_FRAMES: int = 900
const STUCK_PAUSED_FRAMES: int = 300
const TICKS_PER_HOUR: int = SimClock.TICKS_PER_HOUR
const SIZE: Vector2i = Vector2i(1280, 720)
## Residents are classified every this many frames (16 calendar ticks, about 1.3 game minutes, at 4x); the board is
## scanned every frame.
const SAMPLE_FRAMES: int = 4
const HOURS_PER_DAY: int = 24
const DAYS_PER_SEASON: int = 12
const SEASONS: int = 4
const NAV_FINISH_USEC: int = 1 << 30
const BRAIN_SEED_STRIDE: int = 104729
const DEFAULT_FPS: int = 30

var _seed: int = 1
var _policy_name: String = "hands_off"
var _end_hour: int = 48 * HOURS_PER_DAY
var _hours: int = -1
var _out: String = ""
var _csv: String = ""
## The engine's --fixed-fps, as the run's own --fps states it (see TIME): every frame's delta must be 1/_fps.
var _fps: int = DEFAULT_FPS
var _error: String = ""
## The village: untyped, because demo_village.gd names the autoloads, which a main loop's script cannot see when it
## is compiled (they join the tree after `_initialize`); its parts are reached through its accessors below.
var _village: Node = null
var _gm: GameManagerScript = null
var _cast: DemoCastScript = null
var _kitchen: KitchenScript = null
var _food: FoodScript = FoodScript.new()
var _labour: LabourScript = LabourScript.new()
var _farm_watch: FarmWatchScript = FarmWatchScript.new()
var _events: EventsWatchScript = EventsWatchScript.new()
var _policy: PolicyScript = null
var _frame: int = 0
var _started: bool = false
var _hour_seen: int = -1
var _days: Array = []
var _start_usec: int = 0
var _start_frame: int = 0
var _staged: bool = false
## The run fails past this frame (a calendar that advances under a tick a frame is stuck), and counts frames paused.
var _frame_limit: int = 0
var _settled: bool = false
## The calendar tick when the settings were applied, and how far it ran before the run started (the opening hold keeps
## it still: the meta says so, as a check).
var _settle_tick: int = 0
var _ticks_before_start: int = 0
var _paused_frames: int = 0


var _tree: SceneTree = null


func begin(tree: SceneTree) -> void:
	"""Read the arguments and the frame rate, then boot the village in `tree` (or stop with the reason)."""
	_tree = tree
	_read_args(OS.get_cmdline_user_args())
	if not _error.is_empty():
		_fail()
		return
	_staged = ManifestScript.is_staged(ManifestScript.load_manifest())
	_tree.root.size = SIZE
	_village = (load("res://demo/demo_village.tscn") as PackedScene).instantiate()
	_tree.root.add_child(_village)
	_tree.current_scene = _village


func _settle() -> void:
	"""The harness-only settings and the seed, on the village as built (its `_ready` runs when the tree starts, after
	`begin`), on the first frame -- while the demo's opening hold still pauses its clock (see the header)."""
	_settled = true
	_cast = _village.get(&"_cast") as DemoCastScript
	var farm: DemoFarmScript = _village.get(&"_farm") as DemoFarmScript
	if _cast == null or farm == null or _board() == null:
		_error = "the village's cast, farm or work board is not where the harness reads it (demo_village.gd changed?)"
		_fail()
		return
	_cast.set_route_budget(0)
	_settle_tick = farm.sim.calendar.tick
	var tail: Callable = _cast.window_tail
	_cast.window_tail = func() -> void:
		_cast.space().nav.advance_builds(NAV_FINISH_USEC)
		if tail.is_valid():
			tail.call()
	_apply_seed(farm)


func _read_args(args: PackedStringArray) -> void:
	"""--seed, --policy, --days, --hours, --out, --csv (see the header); the first problem into `_error`."""
	for k: int in args.size() - 1:
		var value: String = args[k + 1]
		if args[k].begins_with("--") and not args[k] in FLAGS:
			_error = "unknown argument %s (one of %s)" % [args[k], ", ".join(FLAGS)]
			return
		match args[k]:
			"--seed":
				if not value.is_valid_int():
					_error = "--seed must be an integer, not %s" % value
					return
				_seed = value.to_int()
			"--policy":
				_policy_name = value
			"--days":
				_end_hour = value.to_int() * HOURS_PER_DAY
			"--hours":
				_hours = value.to_int()
			"--out":
				_out = value
			"--csv":
				_csv = value
			"--fps":
				_fps = value.to_int()
	if not _policy_name in POLICIES:
		_error = "unknown --policy %s (one of %s)" % [_policy_name, ", ".join(POLICIES)]
	elif _out.is_empty() or not _out.is_absolute_path():
		_error = "--out must be an absolute path"
	elif not _csv.is_empty() and not _csv.is_absolute_path():
		_error = "--csv must be an absolute path"
	elif _end_hour <= 0 and _hours <= 0:
		_error = "--days or --hours must be positive"
	elif _fps < 1:
		_error = "--fps must be the engine's --fixed-fps (positive)"


static func quotient(a: int, b: int) -> int:
	"""a div b, floored, for a >= 0 and b > 0 (integer division, said once)."""
	@warning_ignore("integer_division")
	return a / b


func _fail() -> void:
	"""Say what stopped the run and exit 2."""
	printerr("BALANCE-RUN error %s" % _error)
	_tree.quit(2)


func frame(delta: float) -> bool:
	"""One frame: boot, then keep the clock running, finish the routing's rebuilds, measure, and stop at the end.
	Always false (the main loop goes on until `quit`)."""
	_frame += 1
	if _tree.root.size != SIZE:
		_tree.root.size = SIZE
	if not _error.is_empty():
		return false
	if _started and absf(delta - 1.0 / float(_fps)) > 1e-6:
		_error = "frame delta %.6f s is not 1/%d s: start godot with --fixed-fps %d (see TIME)" % [delta, _fps, _fps]
		_fail()
		return false
	if not _settled:
		_settle()
		if not _error.is_empty():
			return false
	_cast.space().nav.advance_builds(NAV_FINISH_USEC)
	if not _started:
		_await_opening()
		return false
	_keep_running()
	if _error.is_empty():
		_measure()
		if _kitchen.calendar.hour_index() >= _end_hour:
			_finish()
	return false


func _await_opening() -> void:
	"""Start on the first frame the demo has opened (its opening hold released); fail if it never does."""
	if _time_control().opened:
		_start()
	elif _frame > OPEN_LIMIT_FRAMES:
		_error = "the demo did not open within %d frames" % OPEN_LIMIT_FRAMES
		_fail()


func _start() -> void:
	"""The watchers and the policy on the opened village, then 4x (the settings and the seed were applied at boot)."""
	_gm = _tree.root.get_node(^"GameManager") as GameManagerScript
	_gm.set_process(false)
	_kitchen = (_village.call(&"kitchen") as KitchenNodeScript).kitchen
	var farm: DemoFarmScript = _village.get(&"_farm") as DemoFarmScript
	_bind_watchers(farm)
	if not _error.is_empty():
		return
	_gm.set_speed(SPEED)
	_ticks_before_start = _kitchen.calendar.tick - _settle_tick
	_hour_seen = _kitchen.calendar.hour_index()
	if _hours > 0:
		_end_hour = _hour_seen + _hours
	_frame_limit = _frame + (_end_hour - _hour_seen) * TICKS_PER_HOUR
	_start_usec = Time.get_ticks_usec()
	_start_frame = _frame
	_started = true
	if _policy != null:
		_policy.on_hour(PolicyScript.MORNING_HOUR)


func _apply_seed(farm: DemoFarmScript) -> void:
	"""Re-seed the weather stream and every resident's own choices (see SEEDS)."""
	var seeded: bool = farm.sim.crop_weather().rng().seed_world(_seed).ok
	if not seeded:
		_error = "the weather stream refused seed %d (it must fit int32)" % _seed
		_fail()
		return
	for who: int in _board().resident_count():
		_board().brain_of(who).rng.seed = _seed * BRAIN_SEED_STRIDE + who


func _bind_watchers(farm: DemoFarmScript) -> void:
	"""Every watcher on its subsystem, and the light-touch player when it is this run's policy."""
	var services: ServicesScript = _village.call(&"services") as ServicesScript
	var fishery: FisheryNodeScript = _village.call(&"fishery") as FisheryNodeScript
	_food.bind(_kitchen, farm.pantry, fishery.fishery)
	_labour.bind(_board(), _kitchen)
	_farm_watch.bind(farm.sim)
	var command: DemoCommandScript = _village.get(&"_command") as DemoCommandScript
	if command == null:
		_error = "the village's command layer is not where the harness reads it (demo_village.gd changed?)"
		_fail()
		return
	var works: WorksScript = command.tunnels().ext.works
	var rescue: RefCounted = (_village.call(&"waterplay") as WaterplayScript).rescue
	_events.bind(services.stores, services.incidents, works.events, rescue)
	if _policy_name == "light_touch":
		_policy = PolicyScript.new()
		_policy.bind(farm, _village.call(&"forestry") as ForestryScript, fishery.fishery, services.stores)


func _time_control() -> TimeControlScript:
	"""The village's time controls (the pause ledger, and whether the demo has opened)."""
	return _village.call(&"time_control") as TimeControlScript


func _board() -> BoardScript:
	"""The village's work board."""
	return (_village.call(&"work") as DemoWorkScript).board


func _keep_running() -> void:
	"""Lift a critical incident's autopause as the player's Resume does, and hold 4x; fail on a pause Resume cannot lift
	(a menu, a stall) that lasts, or a calendar that has stopped advancing."""
	if _gm.is_paused():
		if _time_control().ledger.resume() != 0:
			_events.lifted_pause()
		_paused_frames += 1
	else:
		_paused_frames = 0
	if _gm.get_speed() != SPEED:
		_gm.set_speed(SPEED)
	if _paused_frames > STUCK_PAUSED_FRAMES:
		_error = "paused for %d frames and Resume cannot lift it: %s" % [_paused_frames, _gm.get_pause_reason_names()]
		_fail()
	elif _frame > _frame_limit:
		_error = "the calendar is not advancing (frame %d past the limit %d)" % [_frame, _frame_limit]
		_fail()


func _measure() -> void:
	"""This frame's readings: every frame the stores and incidents; every SAMPLE_FRAMES labour and the board; each hour
	crossed the farm and the food, closing a day at its midnight, then the policy's round."""
	_events.frame()
	_labour.scan(_kitchen.calendar.tick)
	if (_frame - _start_frame) % SAMPLE_FRAMES == 0:
		_labour.classify(_kitchen.calendar.tick)
	var hour: int = _kitchen.calendar.hour_index()
	while _hour_seen < hour:
		_hour_seen += 1
		if _hour_seen % HOURS_PER_DAY == 0:
			_close_day(quotient(_hour_seen, HOURS_PER_DAY) - 1, false)
		_food.hour()
		_farm_watch.hour(_hour_seen % HOURS_PER_DAY)
		if _policy != null:
			_policy.on_hour(_hour_seen % HOURS_PER_DAY)


func _close_day(day: int, partial: bool) -> void:
	"""Day `day`'s record from every watcher (`partial`: the run ended inside it)."""
	var season_day: int = day % DAYS_PER_SEASON + 1
	var season: int = quotient(day, DAYS_PER_SEASON) % SEASONS
	var record: Dictionary = {"day": day, "year": quotient(day, DAYS_PER_SEASON * SEASONS), "season": season,
		"season_day": season_day, "partial": partial}
	record.merge(_food.close_day(day))
	record.merge(_labour.close_day())
	record.merge(_farm_watch.close_day(season, season_day))
	record.merge(_events.close_day())
	record["orders"] = _policy.take_orders() if _policy != null else {}
	_days.append(record)
	print("BALANCE-DAY %d closed (frame %d)" % [day, _frame - _start_frame])


func _finish() -> void:
	"""Close a day the run ended inside, write the JSON (and CSV), print the summary line and quit."""
	if _hour_seen % HOURS_PER_DAY != 0:
		_close_day(quotient(_hour_seen, HOURS_PER_DAY), true)
	var real_s: float = float(Time.get_ticks_usec() - _start_usec) / 1000000.0
	var data: Dictionary = {"meta": _meta(real_s), "days": _days, "seasons": Rollup.seasons(_days),
		"totals": Rollup.roll(_days)}
	if not _write(_out, JSON.stringify(data, "", true)):
		return
	if not _csv.is_empty() and not _write(_csv, Csv.of_days(_days)):
		return
	print("BALANCE-RUN ok seed=%d policy=%s days=%d frames=%d real_s=%.1f out=%s" % [_seed, _policy_name, _days.size(),
		_frame - _start_frame, real_s, _out])
	_tree.quit(0)


func _write(path: String, text: String) -> bool:
	"""Write `text` to `path` (its folder made); false (and the run failed) when it cannot."""
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_error = "cannot write %s (%s)" % [path, error_string(FileAccess.get_open_error())]
		_fail()
		return false
	file.store_string(text)
	file.close()
	return true


func _meta(real_s: float) -> Dictionary:
	"""What the run was: its settings, the residents, and what it cost."""
	var names: Array = []
	for who: int in _labour.resident_count():
		names.append(_board().name_of(who))
	return {"seed": _seed, "policy": _policy_name, "end_hour": _end_hour, "fixed_fps": _fps, "speed": SPEED,
		"staged_assets": _staged, "engine": Engine.get_version_info().get("string", ""), "residents": names,
		"frames": _frame - _start_frame, "ticks_before_start": _ticks_before_start, "real_seconds": snappedf(real_s, 0.1), "ticks_per_hour": TICKS_PER_HOUR,
		"harness_settings": ["route budget 0", "nav rebuilds finished inside each frame", "GameManager processing stopped",
			"critical autopause lifted by the ledger's Resume", "weather and resident rngs re-seeded"]}
