extends SceneTree
## THE LIVE DEMO'S SOAK TEST (decision 0921; docs/performance/2026-10-01-soak-test.md). Boots the real
## demo/demo_village.tscn and runs it at 4x for many game days -- twenty by default -- sampling every game hour what a
## leak or a slowdown would show: static memory, the engine's object, node, resource and orphan-node counts, video
## memory where there is a renderer, the errors and warnings printed, and a few of the village's own capped books. Each
## game day's frames are reduced to percentiles of their work and of every system's time, measured by the scale test's
## per-system driver (tools/scale_test/scale_driver.gd, decision 0561) without touching the game's code.
##
##     godot --headless --fixed-fps 60 --path godot --script res://tools/soak/soak_test.gd -- --days 20 \
##         --out /abs/soak.json [--residents 9] [--hours H] [--restart-every-hours H] [--fps 60] [--no-stock]
##         [--no-order]
##
## tools/soak_test.py runs it (sampling the machine's load beside it) and tools/soak_report.py judges the JSON.
##
## TIME. As the scale test (decision 0561 §4): `--fixed-fps` is required and `--fps` must say the same number (60 by
## default). Each frame hands the village exactly 1/fps s of demo time while the engine runs uncapped, so a frame's real
## duration is its work, and at 4x a game day is 150 x fps frames whatever the machine's load. The settlement clock
## (GameManager) still runs on real time and may step 4x down to 2x after a slow frame; the run asks for 4x again and
## counts it (`fallbacks`). A frame the village ran at another speed is not in the day's percentiles.
##
## WHAT CHURNS. Everything that runs on its own: the kitchen's meals at 07:00 and 17:00, the night routine at dusk and
## dawn, songs, the work board's routine tasks, the woods and the farm, the threats (about one a game day, each a
## critical incident that pauses the village), the notices and incidents they post. The harness adds three things a
## player would do (HARNESS ACTIONS); a critical pause or a stall is lifted the next frame as the player's Resume does.
##
## HARNESS ACTIONS, at the village's own hours:
##   * 04:00 (unless --no-stock): the pantry topped up to 3 U of oats and 3 U of carrots per resident, and the water
##     butt filled -- the scale test's stock, kept up, because the demo's own farm runs out of food by day 9 (decision
##     0911) and a kitchen that never cooks churns nothing.
##   * 10:00 (unless --no-order): a work party of up to ORDER_PARTY residents ordered to the village square; at 11:00
##     let go.
##   * every --restart-every-hours game hours: the game menu's "Restart demo" (demo_village.gd `restart`), with the
##     restart leak watch around it (soak_leaks.gd): what of the old village is still alive once the new one is open.
##     The calendar starts again at 06:00 on day 1; the soak's own hours run on.
##
## THE HARNESS'S OWN MEMORY is sized before the first sample (soak_table.gd, soak_days.gd): an hour row in a table
## made for the whole run, a day's frames in buffers made for one day, each day's summary in a packed column made for
## every day. Only a restart adds a small Dictionary (and its leak watch's weak references, let go after the check), so
## what grows between restarts is the village's.
##
## THE END. After the last hour the village is watched as before a restart (soak_leaks.gd), freed, and CLOSE_FRAMES later
## checked: what of it is still alive and unreachable is a leak (`exit_record`). Quitting with the village still in the
## tree would leave the engine's exit report to say the same thing, mixed with the sounds still playing as the process
## quits (an AudioStream and its playback per playing sound, seen as "N resources still in use at exit").
##
## Prints `SOAK-HOUR`, `SOAK-DAY` and `SOAK-RESTART` lines as it goes and `SOAK-DONE <hours> <errors> <failures>` at
## the end; exits 1 when the village failed to open, the run did not finish, or the in-run growth check (soak_growth.gd)
## or an error failed it.

const StressCast := preload("res://demo/stress/stress_cast.gd")
const ProbeScript := preload("res://demo/stress/scale_probe.gd")
const DriverScript := preload("res://tools/scale_test/scale_driver.gd")
const GameManagerScript := preload("res://scripts/systems/game_manager.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const Catalog := preload("res://demo/farm/farm_catalog.gd")
const StoresScript := preload("res://demo/tunnel/tunnel_stores.gd")
const TableScript := preload("res://tools/soak/soak_table.gd")
const DaysScript := preload("res://tools/soak/soak_days.gd")
const LeaksScript := preload("res://tools/soak/soak_leaks.gd")
const ErrorsScript := preload("res://tools/soak/soak_errors.gd")
const GrowthScript := preload("res://tools/soak/soak_growth.gd")
const ResultScript := preload("res://tools/soak/soak_result.gd")

const HOURS_PER_DAY: int = 24
const SPEED: int = 4
## At 4x a 1/fps frame is 120/fps calendar ticks: a day of 18 000 ticks is this many frames per frame-per-second.
const FRAMES_PER_DAY_PER_FPS: int = 150
## A day's frame buffers hold this many days' worth of frames (a 4x day stepped down to 2x takes twice its frames).
const DAY_CAPACITY_FACTOR: int = 3
const OPEN_TIMEOUT_FRAMES: int = 3000
## The run fails when the soak's game hour has not moved for this many frames (a stuck pause, a stopped calendar).
const STUCK_FRAMES: int = 30000
const STOCK_HOUR: int = 4
const ORDER_HOUR: int = 10
const RELEASE_HOUR: int = 11
const ORDER_PARTY: int = 8
const STOCK_ITEMS: Array[StringName] = [&"oats", &"carrot"]
const STOCK_PER_RESIDENT_MILLI: int = 3000
const STOCK_LOT_MILLI: int = 10000
## The in-run growth check skips this many first hours by default (--growth-skip-hours): warm-up (first meals, first
## night, caches filling).
const GROWTH_SKIP_HOURS: int = 24
const CAST_SECTIONS: Array[StringName] = [&"cast.route_serve", &"cast.brains", &"cast.actor_draw", &"cast.nav_builds",
	&"cast.window_tail", &"cast.route_spend"]
const HOUR_COLUMNS: PackedStringArray = ["soak_hour", "village_hour", "restarts", "frames", "wall_ms", "static_kb",
	"static_peak_kb", "objects", "nodes", "resources", "orphans", "video_kb", "texture_kb", "buffer_kb", "errors",
	"warnings", "pauses_lifted", "fallbacks", "managed_nodes", "residents", "notices", "notices_posted",
	"incident_occurrences", "pantry_lots", "pantry_milli", "batches_cooked", "portions_eaten", "orders_given"]

## A day's frame columns (`day_frames`): the frame's work, its processing, all scripts, then each system, then
## CAST_SECTIONS.
const COL_WORK: int = 0
const COL_PROCESS: int = 1
const COL_SCRIPTS: int = 2
const COL_FIRST_SYSTEM: int = 3
## A closed day's own row (`day_info`): its index, every frame it took (measured or not: CPU per frame divides by it),
## its wall-clock span (unix ms) and that day's counts.
const DAY_COLUMNS: PackedStringArray = ["day", "frames_all", "unix_start_ms", "unix_end_ms", "pauses_lifted",
	"fallbacks", "errors", "warnings"]

## At the end the village is freed and the run waits this many frames before checking what of it lived on (see THE
## END): the audio server lets go of a freed player's stream on a later mix.
const CLOSE_FRAMES: int = 30

enum Stage { BOOT, RUN, RESTARTING, CLOSING, DONE }

var residents: int = 9
var hours_asked: int = 20 * HOURS_PER_DAY
var restart_every_hours: int = 0
var fps: int = 60
var stock: bool = true
var give_orders: bool = true
var out_path: String = ""
var growth_skip_hours: int = GROWTH_SKIP_HOURS

var village: Node = null
var driver: DriverScript = DriverScript.new()
var probe: ProbeScript = ProbeScript.new()
var errors_heard: ErrorsScript = ErrorsScript.new()
var leaks: LeaksScript = LeaksScript.new()
var hours: TableScript = TableScript.new()
var day_frames: DaysScript = DaysScript.new()
var failures: PackedStringArray = PackedStringArray()

var stage: Stage = Stage.BOOT
var soak_hour: int = 0
var frame: int = 0
var frames_run: int = 0
var off_speed_frames: int = 0
var pauses_lifted: int = 0
var stall_lifts: int = 0
var fallbacks: int = 0
var orders_given: int = 0
var orders_refused: int = 0
## One row a closed day: what happened in it (DAY_COLUMNS), beside its frames' summary in `day_frames`.
var day_info: TableScript = TableScript.new()
var restart_records: Array = []
## The leak watch around freeing the village at the end (THE END): as a restart's record, without the reopening.
var exit_record: Dictionary = {}
var started_unix: float = 0.0
var _manager: GameManagerScript = null
var _village_hour_seen: int = 0
var _last_progress_frame: int = 0
var _start_usec: int = 0
var _prev_start: int = 0
var _last_harness_us: int = 0
var _day_start_ms: int = 0
var _day_start_frame: int = 0
var _day_counts: PackedInt64Array = PackedInt64Array([0, 0, 0, 0])
var _restart: Dictionary = {}


func _initialize() -> void:
	"""Read the arguments, hear the errors, size the harness's tables and boot the village."""
	_read_args(OS.get_cmdline_user_args())
	OS.add_logger(errors_heard)
	StressCast.override_count = residents if residents != 9 else 0
	Engine.max_fps = 0
	root.size = Vector2i(1920, 1080)
	_size_tables()
	started_unix = Time.get_unix_time_from_system()
	_start_usec = Time.get_ticks_usec()
	village = (load("res://demo/demo_village.tscn") as PackedScene).instantiate()
	root.add_child(village)
	current_scene = village
	driver.name = "ScaleDriver"
	driver.on_frame = _on_frame
	root.add_child(driver)


func _read_args(args: PackedStringArray) -> void:
	"""--residents, --days, --hours, --restart-every-hours, --fps, --out, --growth-skip-hours, --no-stock, --no-order."""
	stock = not args.has("--no-stock")
	give_orders = not args.has("--no-order")
	for k: int in args.size() - 1:
		var value: String = args[k + 1]
		match args[k]:
			"--residents":
				residents = clampi(value.to_int(), 1, StressCast.MAX_RESIDENTS)
			"--days":
				hours_asked = maxi(value.to_int(), 1) * HOURS_PER_DAY
			"--hours":
				hours_asked = maxi(value.to_int(), 1)
			"--restart-every-hours":
				restart_every_hours = maxi(value.to_int(), 0)
			"--fps":
				fps = maxi(value.to_int(), 1)
			"--out":
				out_path = value
			"--growth-skip-hours":
				growth_skip_hours = maxi(value.to_int(), 0)


func _size_tables() -> void:
	"""The hourly table for the whole run and a day's frame buffers, before the first sample."""
	hours.setup(HOUR_COLUMNS, hours_asked + 2)
	var names: PackedStringArray = ["work_us", "process_us", "scripts_us"]  # COL_WORK, COL_PROCESS, COL_SCRIPTS
	for system: StringName in driver.systems:
		names.append("sys." + String(system))
	for section: StringName in CAST_SECTIONS:
		names.append(String(section))
	@warning_ignore("integer_division")
	var days: int = hours_asked / HOURS_PER_DAY + 2
	day_frames.setup(names, FRAMES_PER_DAY_PER_FPS * fps * DAY_CAPACITY_FACTOR, days)
	day_info.setup(DAY_COLUMNS, days)


# --- frames ----------------------------------------------------------------------------------------------------------

func _on_frame(delta: float) -> void:
	"""The start of a frame (the driver calls it before any script runs): book the frame before, then steer the run."""
	frame += 1
	var frame_us: int = driver.frame_start_usec - _prev_start
	var process_us: int = driver.process_end_usec - _prev_start
	_prev_start = driver.frame_start_usec
	var started: int = Time.get_ticks_usec()
	match stage:
		Stage.BOOT:
			_wait_for_open()
		Stage.RESTARTING:
			_wait_for_reopen()
		Stage.CLOSING:
			_close()
		Stage.RUN:
			_run_frame(delta, frame_us, process_us)
	_last_harness_us = Time.get_ticks_usec() - started
	driver.begin_frame()
	probe.clear()


func _run_frame(delta: float, frame_us: int, process_us: int) -> void:
	"""A running frame: check the step, book it, keep the village at 4x and unpaused, and follow the game hours."""
	if absf(delta - 1.0 / float(fps)) > 0.000001:
		_fail("a frame of %.4f s, not 1/%d: run with --fixed-fps %d (see TIME)" % [delta, fps, fps])
		return
	if frame - _last_progress_frame > STUCK_FRAMES:
		_fail("the game hour has not moved for %d frames (soak hour %d)" % [STUCK_FRAMES, soak_hour])
		return
	_book(frame_us, process_us)
	_lift_pause()
	if _manager.get_speed() != SPEED:
		fallbacks += 1
		_manager.set_speed(SPEED)
	_follow_hours()


func _book(frame_us: int, process_us: int) -> void:
	"""Book the frame just finished into today's samples -- when the village ran it at 4x."""
	frames_run += 1
	if int((_cast().get("clock") as Object).get("speed")) != SPEED:
		off_speed_frames += 1
		return
	day_frames.set_value(COL_WORK, maxi(frame_us - _last_harness_us, 0))
	day_frames.set_value(COL_PROCESS, process_us)
	var scripts: int = 0
	for k: int in driver.systems.size():
		day_frames.set_value(COL_FIRST_SYSTEM + k, driver.frame_usec[k])
		scripts += driver.frame_usec[k]
	day_frames.set_value(COL_SCRIPTS, scripts)
	var base: int = COL_FIRST_SYSTEM + driver.systems.size()
	for k: int in CAST_SECTIONS.size():
		day_frames.set_value(base + k, probe.usec_of(CAST_SECTIONS[k]))
	day_frames.commit()


func _lift_pause() -> void:
	"""A pause the run did not ask for: a critical incident's (the player's Resume lifts it) or a stall's (acknowledged
	as the stall banner's Resume does). Counted."""
	if _manager.get_effective_speed() != 0:
		return
	pauses_lifted += 1
	var time: Object = village.call(&"time_control")
	if int(time.call(&"resume")) != 0 and _manager.get_effective_speed() != 0:
		return
	stall_lifts += 1
	_manager.acknowledge_overload()
	time.call(&"resume")
	if _manager.is_paused():
		_manager.resume_game()


# --- opening and restarting ------------------------------------------------------------------------------------------

func _wait_for_open() -> void:
	"""Until the demo has opened running, wait; then take over every script node and start the run."""
	if not _opened(village):
		if frame > OPEN_TIMEOUT_FRAMES:
			_fail("the village never opened")
		return
	_manager = root.get_node(^"GameManager") as GameManagerScript
	print("SOAK boot_ms %d" % roundi((Time.get_ticks_usec() - _start_usec) / 1000.0))
	driver.take_over(root)
	_on_village_open()
	_day_start_ms = roundi(Time.get_unix_time_from_system() * 1000.0)
	_day_start_frame = frame
	_sample_hour()
	stage = Stage.RUN


func _on_village_open() -> void:
	"""The opened village (first or restarted): the probe on its cast, its pantry, 4x, and its hour as the baseline."""
	_cast().set("probe", probe)
	_village_hour_seen = int(_calendar().call(&"hour_index"))
	_last_progress_frame = frame
	if stock:
		_top_up_pantry()
	_manager.set_speed(SPEED)
	print("SOAK residents %d managed_nodes %d" % [int(_cast().call(&"actor_count")), driver.managed_count()])


func _opened(scene: Node) -> bool:
	"""Whether `scene` (a village) has opened running (its prewarm done)."""
	var time: Object = scene.get("_time") if scene != null else null
	return time != null and bool(time.get("opened"))


func _start_restart() -> void:
	"""The game menu's Restart demo, with the leak watch around it (see HARNESS ACTIONS)."""
	_cast().set("probe", null)
	var before: Dictionary = _monitors()
	var watch_started: int = Time.get_ticks_usec()
	var watched: int = leaks.watch(village)
	_restart = {"soak_hour": soak_hour, "watched": watched, "watch_ms": _ms(Time.get_ticks_usec() - watch_started),
		"before": before, "old_id": village.get_instance_id(), "frames": 0, "started_usec": Time.get_ticks_usec()}
	village.call(&"restart")
	village = null
	stage = Stage.RESTARTING
	print("SOAK-RESTART begin at soak hour %d, %d objects watched" % [soak_hour, watched])


func _wait_for_reopen() -> void:
	"""Until the new village has opened, wait (its frames are not measured); then check what of the old one lived on."""
	_restart["frames"] = int(_restart["frames"]) + 1
	var scene: Node = current_scene
	if scene == null or scene.get_instance_id() == int(_restart["old_id"]) or not _opened(scene):
		if int(_restart["frames"]) > OPEN_TIMEOUT_FRAMES:
			_fail("the village did not reopen after the restart at soak hour %d" % soak_hour)
		return
	village = scene
	_restart["reopen_ms"] = _ms(Time.get_ticks_usec() - int(_restart["started_usec"]))
	_restart["leaks"] = leaks.check(root)
	_restart["after"] = _monitors()
	_restart.erase("started_usec")
	_restart.erase("old_id")
	restart_records.append(_restart)
	print("SOAK-RESTART done %s" % JSON.stringify(_restart["leaks"]))
	_restart = {}
	_on_village_open()
	stage = Stage.RUN


# --- the hours and the days ------------------------------------------------------------------------------------------

func _follow_hours() -> void:
	"""Each game hour the village's calendar crosses is a soak hour: sample it, then act on it."""
	var hour: int = int(_calendar().call(&"hour_index"))
	while _village_hour_seen < hour and stage == Stage.RUN:
		_village_hour_seen += 1
		soak_hour += 1
		_last_progress_frame = frame
		_sample_hour()
		_on_hour(_village_hour_seen % HOURS_PER_DAY)


func _on_hour(hour_of_day: int) -> void:
	"""The soak hour just sampled: close a day, the harness's actions, a restart, or the end."""
	if soak_hour % HOURS_PER_DAY == 0:
		_close_day()
	if soak_hour >= hours_asked:
		_finish()
		return
	if hour_of_day == STOCK_HOUR and stock:
		_top_up_pantry()
	elif hour_of_day == ORDER_HOUR and give_orders:
		_give_order()
	elif hour_of_day == RELEASE_HOUR and give_orders:
		_cast().call(&"release", _party())
	if restart_every_hours > 0 and soak_hour % restart_every_hours == 0:
		_start_restart()


func _sample_hour() -> void:
	"""One row of the hourly table: the monitors, the counters and the village's own books."""
	var monitors: Dictionary = _monitors()
	for name: String in monitors:
		hours.set_value(hours.column(name), int(monitors[name]))
	for pair: Array in [["soak_hour", soak_hour], ["village_hour", _village_hour_seen % HOURS_PER_DAY],
			["restarts", restart_records.size()], ["frames", frames_run],
			["wall_ms", _ms(Time.get_ticks_usec() - _start_usec)], ["errors", errors_heard.errors()],
			["warnings", errors_heard.warnings()], ["pauses_lifted", pauses_lifted], ["fallbacks", fallbacks],
			["managed_nodes", driver.managed_count()], ["orders_given", orders_given]]:
		hours.set_value(hours.column(pair[0]), int(pair[1]))
	_sample_books()
	hours.commit()
	if soak_hour % 6 == 0:
		print("SOAK-HOUR %d static_kb=%d objects=%d nodes=%d resources=%d orphans=%d errors=%d" % [soak_hour,
			monitors["static_kb"], monitors["objects"], monitors["nodes"], monitors["resources"], monitors["orphans"],
			errors_heard.errors()])


func _sample_books() -> void:
	"""The village's own capped books into the row being filled: residents, notices, incidents, pantry, kitchen."""
	var services: Object = village.call(&"services")
	var notices: Object = services.get("notices")
	var kitchen: Object = (village.call(&"kitchen") as Object).get("kitchen")
	var pantry: Object = kitchen.get("pantry")
	for pair: Array in [["residents", _cast().call(&"actor_count")], ["notices", notices.call(&"count")],
			["notices_posted", notices.get("rows_posted")],
			["incident_occurrences", (services.get("incidents") as Object).get("occurrences")],
			["pantry_lots", pantry.call(&"lot_count")], ["pantry_milli", pantry.call(&"total_milli")],
			["batches_cooked", kitchen.get("batches_cooked")], ["portions_eaten", kitchen.get("portions_eaten")]]:
		hours.set_value(hours.column(pair[0]), int(pair[1]))


func _monitors() -> Dictionary:
	"""The engine's memory and object monitors now (kilobytes and counts)."""
	return {"static_kb": _kb(Performance.MEMORY_STATIC), "static_peak_kb": _kb(Performance.MEMORY_STATIC_MAX),
		"objects": _count(Performance.OBJECT_COUNT), "nodes": _count(Performance.OBJECT_NODE_COUNT),
		"resources": _count(Performance.OBJECT_RESOURCE_COUNT),
		"orphans": _count(Performance.OBJECT_ORPHAN_NODE_COUNT),
		"video_kb": _kb(Performance.RENDER_VIDEO_MEM_USED), "texture_kb": _kb(Performance.RENDER_TEXTURE_MEM_USED),
		"buffer_kb": _kb(Performance.RENDER_BUFFER_MEM_USED)}


static func _ms(usec: int) -> int:
	"""Microseconds as whole milliseconds (floored)."""
	@warning_ignore("integer_division")
	return usec / 1000


static func _kb(monitor: Performance.Monitor) -> int:
	"""A byte monitor in kilobytes."""
	return roundi(Performance.get_monitor(monitor) / 1024.0)


static func _count(monitor: Performance.Monitor) -> int:
	"""A count monitor."""
	return roundi(Performance.get_monitor(monitor))


func _close_day() -> void:
	"""Day `soak_hour / 24 - 1`'s record: its frames' percentiles (soak_days.gd) and what happened in it (`day_info`)."""
	var now_ms: int = roundi(Time.get_unix_time_from_system() * 1000.0)
	var kept: int = day_frames.close_day()
	@warning_ignore("integer_division")
	var day: int = soak_hour / HOURS_PER_DAY - 1
	var counts: PackedInt64Array = PackedInt64Array([pauses_lifted, fallbacks, errors_heard.errors(),
		errors_heard.warnings()])
	var row: PackedInt64Array = PackedInt64Array([day, frame - _day_start_frame, _day_start_ms, now_ms])
	for k: int in counts.size():
		row.append(counts[k] - _day_counts[k])
	for k: int in row.size():
		day_info.set_value(k, row[k])
	day_info.commit()
	_day_counts = counts
	_day_start_ms = now_ms
	_day_start_frame = frame
	if kept >= 0:
		var summary: Dictionary = day_frames.summary_of(kept)
		var work: Dictionary = summary["columns"]["work_us"]
		print("SOAK-DAY %d frames=%d work_us p50=%d p95=%d p99=%d errors=%d" % [day, summary["frames"], work["p50"],
			work["p95"], work["p99"], errors_heard.errors()])


func day_records() -> Array:
	"""Every closed day: its frames' summary with `day_info`'s row merged in (for the JSON)."""
	var out: Array = []
	for row: int in mini(day_info.row_count(), day_frames.days_kept()):
		var record: Dictionary = day_frames.summary_of(row)
		for k: int in DAY_COLUMNS.size():
			record[DAY_COLUMNS[k]] = day_info.value(row, k)
		record["unix_start"] = day_info.value(row, 2) / 1000.0
		record["unix_end"] = day_info.value(row, 3) / 1000.0
		out.append(record)
	return out


# --- the harness's actions -------------------------------------------------------------------------------------------

func _top_up_pantry() -> void:
	"""The pantry up to STOCK_PER_RESIDENT_MILLI of each STOCK_ITEMS per resident, and the water butt full."""
	var kitchen: Object = (village.call(&"kitchen") as Object).get("kitchen")
	var pantry: Object = kitchen.get("pantry")
	var read := IntMath.IntResult.new()
	var want: int = STOCK_PER_RESIDENT_MILLI * int(_cast().call(&"actor_count"))
	for key: StringName in STOCK_ITEMS:
		var item: int = Catalog.ITEM_KEYS.find(key)
		var short: int = want - int(pantry.call(&"milli_of", item))
		while short > 0 and pantry.call(&"add_into", item, mini(STOCK_LOT_MILLI, short), 0, read):
			short -= mini(STOCK_LOT_MILLI, short)
	(kitchen.get("stores") as Object).set("water_milli_u", StoresScript.WATER_CAP_MILLI_U)


func _give_order() -> void:
	"""A work party to the village square (scale_test.gd's group order, smaller): counted given or refused."""
	var space: Object = _cast().call(&"space")
	var names: Array = space.get("poi_names")
	var spot: Vector2 = (space.get("poi_position") as PackedVector2Array)[maxi(names.find(&"square_west"), 0)]
	var result: Dictionary = _cast().call(&"order_move", _party(), Vector3(spot.x, 0.0, spot.y))
	if bool(result.get("ok", false)):
		orders_given += 1
	else:
		orders_refused += 1


func _party() -> PackedInt32Array:
	"""The work party: the first ORDER_PARTY residents (all of them, when fewer)."""
	return PackedInt32Array(range(mini(int(_cast().call(&"actor_count")), ORDER_PARTY)))


# --- the end ---------------------------------------------------------------------------------------------------------

func _finish() -> void:
	"""The last hour: pause, watch the village and free it (see THE END); `_close` judges once it has gone."""
	stage = Stage.CLOSING
	_manager.pause_game()
	_cast().set("probe", null)
	exit_record = {"soak_hour": soak_hour, "watched": leaks.watch(village), "frames": 0}
	village.queue_free()
	village = null


func _close() -> void:
	"""CLOSE_FRAMES after the village was freed: check what of it lived on, judge the run, write it and quit (1 on any
	failure or error)."""
	exit_record["frames"] = int(exit_record["frames"]) + 1
	if int(exit_record["frames"]) < CLOSE_FRAMES:
		return
	stage = Stage.DONE
	exit_record["leaks"] = leaks.check(root)
	var growth: Array = GrowthScript.check(hours, growth_skip_hours)
	failures.append_array(GrowthScript.failures(growth))
	for record: Dictionary in restart_records + [exit_record]:
		if int((record["leaks"] as Dictionary)["unreachable"]) > 0:
			failures.append("freeing the village at soak hour %d left %d objects unreachable: %s" % [record[
				"soak_hour"], record["leaks"]["unreachable"], record["leaks"]["unreachable_by_label"]])
	if errors_heard.errors() > 0:
		failures.append("%d errors were printed: %s" % [errors_heard.errors(), errors_heard.summary()["first_errors"]])
	_write(ResultScript.build(self, growth))
	for line: String in failures:
		print("SOAK-FAIL %s" % line)
	print("SOAK-DONE %d %d %d" % [soak_hour, errors_heard.errors(), failures.size()])
	quit(1 if not failures.is_empty() else 0)


func _write(result: Dictionary) -> void:
	"""The result to `out_path` (when given)."""
	if out_path.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(out_path.get_base_dir())
	var file := FileAccess.open(out_path, FileAccess.WRITE)
	if file == null:
		failures.append("cannot write %s (give an absolute path)" % out_path)
		return
	file.store_string(JSON.stringify(result, "\t"))
	file.close()


func _fail(why: String) -> void:
	"""Give up: write what there is, say why and quit with 1."""
	stage = Stage.DONE
	failures.append(why)
	_write(ResultScript.build(self, []))
	print("SOAK-FAIL %s" % why)
	print("SOAK-DONE %d %d %d" % [soak_hour, errors_heard.errors(), failures.size()])
	quit(1)


# --- reading the village ---------------------------------------------------------------------------------------------

func _cast() -> Node:
	"""The demo cast."""
	return village.get("_cast")


func _calendar() -> Object:
	"""The demo's one calendar."""
	return (village.call(&"services") as Object).get("calendar")
