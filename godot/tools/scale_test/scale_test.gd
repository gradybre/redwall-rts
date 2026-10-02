extends SceneTree
## THE LIVE DEMO'S SCALE TEST (decision 0561; docs/performance/2026-10-01-scale-test.md). Boots the real
## demo/demo_village.tscn with N residents (demo/stress/stress_cast.gd), runs a plan of game hours at 1x and 4x through
## a meal and a night, and writes what each frame cost -- per system, per engine stage -- with memory, the stalls, a
## group order's routing and every resident's wait for a route.
##
##     godot --headless --fixed-fps 60 --path godot --script res://tools/scale_test/scale_test.gd -- --residents 50 \
##         --out /tmp/scale_50.json [--csv /tmp/scale_50.csv] [--plan full|short] [--size 1920x1080] [--no-stock]
##
## `--fixed-fps 60` IS REQUIRED (the run refuses without it): every frame then hands the village exactly a 60 Hz
## frame's demo time while the engine runs UNCAPPED (vsync off, no frame cap), so a frame's real duration is the work
## it took and nothing else -- no sleep to a cap, no vsync wait. Without --headless it opens a window and the render's
## CPU and GPU times are real. tools/scale_test.py runs the matrix and tabulates it.
##
## THE PLAN (full): 4x from 06:00 to 06:50 (a warm-up, not reported); 1x from 06:50 to 07:40 (breakfast is called at
## 07:00 -- on day 1 its cook, up from 05:00, has nothing ready, so this is the quiet 1x); a group order of a work
## party (ORDER_GROUP; `_give_order`) at 07:40, timed until the routing desk has served it (at 1x), then released; 4x
## to 16:50; 1x from 16:50 to 17:40 (supper is called at 17:00); 4x to 19:50; 1x from 19:50 to 20:40 (bed at dusk,
## 20:00). `short` (the suite's): 1x for 150 ticks, the order, 4x to tick 900.
##
## 4X THAT FALLS BACK. The settlement clock steps 4x down to 2x when a frame is slower than it can catch up on (about
## 66.7 ms at 4x; scripts/core/sim_clock.gd). A phase's speed is asked for again whenever the clock has stepped it
## down -- so its frames are measured at the speed it names. Every frame records the speed the village actually ran
## it at (`speed`: the demo clock's, read before the cast steps the next frame) beside the settlement clock's after it
## (`sim_speed`: 2 on the frame that stepped 4x down). The step-down lands in the settlement clock's own processing,
## after the cast has stepped, so the frame that caused it still ran at the phase's speed and stays in its statistics.
## A phase's statistics keep the frames the village ran at its speed; `fallbacks` counts the step-downs.
##
## FRAMES. A frame's columns are read at the start of the next (scale_driver.gd runs first in it): its real duration,
## its processing (the driver's start to the end mark, scale_end_mark.gd), the render's CPU and GPU times (windowed),
## each system's script time and the cast's own sections (demo/stress/scale_probe.gd). The harness's own time is booked
## apart and taken off. (Performance.TIME_PROCESS is not used: 4.7.2 refreshes it about once a second.)
##
## A 60 HZ VIRTUAL CLOCK. Uncapped, a fast frame is shorter than a real game's 16.67 ms one, and the routing desk -- one
## budgeted window a frame -- would serve more windows a real second than the game ever gets. So waits (a resident's
## for its route, the group order's) are counted in frames and in VIRTUAL time: each frame counts as its real duration
## or 16.67 ms, whichever is longer -- what the capped game would show.
##
## THE PANTRY IS STOCKED (unless --no-stock). The demo opens on day 1 with nothing harvested, so the kitchen has
## nothing to cook and calls nobody to a meal: no meal-call burst would be measured at all. At open the harness puts
## oats and carrots -- porridge and soup, both meals' worth for every resident, as far as the covered store has room --
## into the pantry in lots of STOCK_LOT_MILLI, and fills the water butt (`_stock_pantry`; the report's `stocked`).
##
## A pause the run did not ask for -- a stall's diagnostic pause, a critical incident -- is counted and lifted (the
## overload acknowledged, the ledger resumed) so the plan runs on.
##
## Prints `SCALE <key> <value>` lines and `SCALE-DONE <residents> <frames> <errors>`; exits 1 when the village failed to
## open, the plan did not finish or an invariant failed (scale_checks.gd).

const StressCast := preload("res://demo/stress/stress_cast.gd")
const ProbeScript := preload("res://demo/stress/scale_probe.gd")
const DriverScript := preload("res://tools/scale_test/scale_driver.gd")
const RecordScript := preload("res://tools/scale_test/scale_record.gd")
const ChecksScript := preload("res://tools/scale_test/scale_checks.gd")
const ReportScript := preload("res://tools/scale_test/scale_report.gd")
const GameManagerScript := preload("res://scripts/systems/game_manager.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const Catalog := preload("res://demo/farm/farm_catalog.gd")
const StoresScript := preload("res://demo/tunnel/tunnel_stores.gd")

## [phase name, speed, until calendar tick] -- tick 0 is 06:00 of spring day 1. An "order" phase runs at 1x until the
## group order is routed.
const PLAN_FULL: Array = [["4x_warmup", 4, 625], ["1x_breakfast", 1, 1250], ["order", 1, -1], ["4x_day", 4, 8125],
	["1x_supper", 1, 8750], ["4x_evening", 4, 10375], ["1x_dusk", 1, 11000]]
const PLAN_SHORT: Array = [["1x_breakfast", 1, 150], ["order", 1, -1], ["4x_day", 4, 900]]
## Bursts reported apart: [name, from tick, to tick].
const BURSTS: Array = [["breakfast_call_0700", 750, 1125], ["supper_call_1700", 8250, 8625],
	["bed_at_dusk_2000", 10500, 10875]]
const OPEN_TIMEOUT_FRAMES: int = 3000
const FRAME_USEC_AT_60: int = 16667
## The pantry's stock (see THE PANTRY IS STOCKED): per resident per meal a batch's input for half a batch, two meals,
## put in lots of this size.
const STOCK_ITEMS: Array[StringName] = [&"oats", &"carrot"]
const STOCK_PER_RESIDENT_MILLI: int = 3000
const STOCK_LOT_MILLI: int = 10000
const ORDER_TIMEOUT_FRAMES: int = 1800
## The run gives up (`_fail`) past this many times the plan's expected frames: a pause it cannot lift, a stalled
## calendar -- so a suite never hangs on it.
const WATCHDOG_FACTOR: int = 3
## The group order's party: this many residents (all of them, when fewer).
const ORDER_GROUP: int = 16
## A plan with no task is booked by the brain's order (resident_brain.gd ORDER_*).
const ORDER_KINDS: Array[String] = ["routine", "order_move", "order_work", "order_dig", "order_task"]
## After the order is served, the residents stand this many frames before they are released.
const ORDER_HOLD_FRAMES: int = 60
const CAST_SECTIONS: PackedStringArray = ["cast.route_serve", "cast.brains", "cast.actor_draw", "cast.nav_builds",
	"cast.window_tail", "cast.route_spend"]
const BASE_COLUMNS: PackedStringArray = ["phase", "speed", "sim_speed", "tick", "frame_us", "process_us",
	"render_cpu_us", "gpu_us", "harness_us", "scripts_us", "route_waiting", "plan_estimate_us", "plans", "plan_max_us",
	"walking", "static_kb", "nodes", "objects", "video_kb", "draw_calls"]

var residents: int = 9
var out_path: String = ""
var csv_path: String = ""
var plan: Array = PLAN_FULL
var stock: bool = true
## What `_stock_pantry` put in: item key -> milli.
var stocked: Dictionary = {}
var fps: int = 60
var _watchdog_frames: int = 0
var size: Vector2i = Vector2i(1920, 1080)

var village: Node = null
var driver: DriverScript = DriverScript.new()
var probe: ProbeScript = ProbeScript.new()
var record: RecordScript = RecordScript.new()
var checks: ChecksScript = ChecksScript.new()
var errors: PackedStringArray = PackedStringArray()

var _phase: int = -1
var _frame: int = 0
var _open_frame: int = -1
var _boot_usec: int = 0
var _manager: GameManagerScript = null
var _speed_col: int = -1
## The unasked pauses lifted, the times the clock stepped a phase's speed down (see 4X THAT FALLS BACK), and the clock
## diagnostics heard.
var unasked_pauses: int = 0
var fallbacks: int = 0
var diagnostics: PackedStringArray = PackedStringArray()
## The group order: when it was given, its call's time, when the desk had served it, the spend meanwhile.
var order: Dictionary = {}
## Each resident's wait for a route: when it joined the desk's queue (usec, -1: not waiting); each finished wait and
## its phase.
var _wait_since: PackedInt64Array = PackedInt64Array()
var _waiting_now: PackedByteArray = PackedByteArray()
var _waits: PackedInt64Array = PackedInt64Array()
var _wait_phase: PackedInt32Array = PackedInt32Array()
## Each resident's plans as last seen on the desk's tally (route_desk.gd `tally`), and the plans by what the resident
## was doing when it planned: kind -> [plans, microseconds, the longest].
var _seen_plans: PackedInt32Array = PackedInt32Array()
var _seen_plan_usec: PackedInt64Array = PackedInt64Array()
var plans_by_kind: Dictionary = {}
## Residents with no POI slot at open (`_off_poi`).
var off_poi_starts: int = 0
## The harness's own time in the frame before (booked against the engine's process time, which includes it).
var _last_harness_us: int = 0
## The frame before's start (real usec), and the 60 Hz virtual clock (see A 60 HZ VIRTUAL CLOCK).
var _prev_start: int = 0
var virtual_usec: int = 0
var _quitting: bool = false


func _initialize() -> void:
	"""Read the arguments, ask for the stress cast, cap the frame rate and boot the village."""
	_read_args()
	StressCast.override_count = residents
	Engine.max_fps = 0
	root.size = size
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		DisplayServer.window_set_size(size)
		RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	_boot_usec = Time.get_ticks_usec()
	village = (load("res://demo/demo_village.tscn") as PackedScene).instantiate()
	root.add_child(village)
	current_scene = village
	driver.name = "ScaleDriver"
	driver.on_frame = _on_frame
	root.add_child(driver)


func _read_args() -> void:
	"""--residents, --out, --csv, --plan, --size, --no-stock."""
	var args: PackedStringArray = OS.get_cmdline_user_args()
	stock = not args.has("--no-stock")
	for k: int in args.size() - 1:
		var value: String = args[k + 1]
		match args[k]:
			"--residents":
				residents = clampi(value.to_int(), 1, StressCast.MAX_RESIDENTS)
			"--out":
				out_path = value
			"--csv":
				csv_path = value
			"--plan":
				plan = PLAN_SHORT if value == "short" else PLAN_FULL
			"--size":
				var parts: PackedStringArray = value.split("x")
				if parts.size() == 2 and parts[0].to_int() > 0 and parts[1].to_int() > 0:
					size = Vector2i(parts[0].to_int(), parts[1].to_int())


func _on_frame(delta: float) -> void:
	"""The start of a frame (the driver calls it before any script runs): book the frame before, then steer the plan."""
	_frame += 1
	if root.size != size:
		root.size = size
	var frame_us: int = driver.frame_start_usec - _prev_start
	var process_us: int = driver.process_end_usec - _prev_start
	_prev_start = driver.frame_start_usec
	if _quitting:
		return
	if _open_frame < 0:
		_wait_for_open()
		return
	var started: int = Time.get_ticks_usec()
	if absf(delta - 1.0 / float(fps)) > 0.000001:
		_fail("a frame of %.4f s, not 1/%d: run with --fixed-fps %d (see FRAMES)" % [delta, fps, fps])
		return
	if _frame > _watchdog_frames:
		_fail("the plan did not finish in %d frames (phase %s)" % [_watchdog_frames, phase_name(_phase)])
		return
	virtual_usec += maxi(frame_us, FRAME_USEC_AT_60)
	_book(frame_us, process_us)
	_lift_unasked_pause()
	_follow_routes()
	_follow_plans()
	_steer()
	_last_harness_us = Time.get_ticks_usec() - started
	driver.begin_frame()
	probe.clear()


func _wait_for_open() -> void:
	"""Until the demo has opened running (its prewarm done), wait; then take over and start the plan."""
	var time: Object = village.get("_time")
	if time == null or not bool(time.get("opened")):
		if _frame > OPEN_TIMEOUT_FRAMES:
			_fail("the village never opened")
		return
	var started: int = Time.get_ticks_usec()
	_open_frame = _frame
	_watchdog_frames = _frame + _expected_frames() * WATCHDOG_FACTOR
	_manager = root.get_node(^"GameManager") as GameManagerScript
	_manager.clock_diagnostic.connect(func(message: String) -> void: diagnostics.append(message))
	(time.get("ledger") as Object).set("auto_critical", false)
	print("SCALE boot_ms %d" % roundi((Time.get_ticks_usec() - _boot_usec) / 1000.0))
	_cast().set("probe", probe)
	driver.take_over(root)
	_define_columns()
	_wait_since.resize(int(_cast().call(&"actor_count")))
	_wait_since.fill(-1)
	_waiting_now.resize(_wait_since.size())
	_desk().set("tally", true)
	_seen_plans.resize(_wait_since.size())
	_seen_plan_usec.resize(_wait_since.size())
	print("SCALE residents %d" % int(_cast().call(&"actor_count")))
	print("SCALE managed_nodes %d" % driver.managed_count())
	off_poi_starts = _off_poi()
	print("SCALE off_poi_starts %d" % off_poi_starts)
	if stock:
		_stock_pantry()
	_last_harness_us = Time.get_ticks_usec() - started
	_enter_phase(0)


func _off_poi() -> int:
	"""How many residents hold no POI slot at open: past the village's slots the cast starts them on a small ring round
	the origin (demo_cast.gd `_place`), stacked on one another."""
	var off: int = 0
	for who: int in int(_cast().call(&"actor_count")):
		if int(((_cast().call(&"actor", who) as Object).get("brain") as Object).get("poi")) < 0:
			off += 1
	return off


func _expected_frames() -> int:
	"""The frames the plan should take: each phase's ticks at its speed (a 60 Hz frame is half a tick at 1x), and the
	order's longest wait."""
	var frames: int = 0
	var tick: int = 0
	for row: Array in plan:
		if int(row[2]) < 0:
			frames += ORDER_TIMEOUT_FRAMES + ORDER_HOLD_FRAMES
			continue
		@warning_ignore("integer_division")
		frames += (int(row[2]) - tick) * 2 / int(row[1])
		tick = int(row[2])
	return frames


func _stock_pantry() -> void:
	"""Put both meals' food for everyone in the pantry and fill the water butt (see THE PANTRY IS STOCKED)."""
	var kitchen: Object = (village.call(&"kitchen") as Object).get("kitchen")
	var pantry: Object = kitchen.get("pantry")
	var stores: Object = kitchen.get("stores")
	var read := IntMath.IntResult.new()
	var want: int = STOCK_PER_RESIDENT_MILLI * int(_cast().call(&"actor_count"))
	for key: StringName in STOCK_ITEMS:
		var item: int = Catalog.ITEM_KEYS.find(key)
		var put: int = 0
		while put < want and pantry.call(&"add_into", item, mini(STOCK_LOT_MILLI, want - put), 0, read):
			put += mini(STOCK_LOT_MILLI, want - put)
		stocked[String(key)] = put
	stores.set("water_milli_u", StoresScript.WATER_CAP_MILLI_U)
	stocked["water"] = StoresScript.WATER_CAP_MILLI_U
	print("SCALE stocked %s" % stocked)


func _define_columns() -> void:
	"""The record's columns: the base ones, every system's, the cast's sections."""
	var names: PackedStringArray = BASE_COLUMNS.duplicate()
	for system: StringName in driver.systems:
		names.append("sys." + String(system))
	names.append_array(CAST_SECTIONS)
	record.define(names)
	_speed_col = record.column("speed")


func _book(frame_us: int, process_us: int) -> void:
	"""Book the frame just finished into a row (its speed and tick are as this frame starts: what it ran at)."""
	record.set_value(record.column("phase"), _phase)
	record.set_value(_speed_col, int((_cast().get("clock") as Object).get("speed")))
	record.set_value(record.column("sim_speed"), _manager.get_effective_speed())
	record.set_value(record.column("tick"), calendar_tick())
	record.set_value(record.column("frame_us"), frame_us)
	record.set_value(record.column("process_us"), process_us)
	record.set_value(record.column("harness_us"), _last_harness_us)
	_book_render()
	_book_memory()
	record.set_value(record.column("route_waiting"), _desk().call(&"waiting"))
	record.set_value(record.column("plan_estimate_us"), int(_desk().get("estimate_usec")))
	var walking: PackedByteArray = (_cast().call(&"space") as Object).get("resident_walking")
	record.set_value(record.column("walking"), walking.count(1))
	var scripts: int = 0
	for k: int in driver.systems.size():
		record.set_value(record.column("sys." + String(driver.systems[k])), driver.frame_usec[k])
		scripts += driver.frame_usec[k]
	record.set_value(record.column("scripts_us"), scripts)
	for section: String in CAST_SECTIONS:
		record.set_value(record.column(section), probe.usec_of(StringName(section)))
	record.commit()


func _book_render() -> void:
	"""The render's CPU and GPU times of the frame (0 headless)."""
	if DisplayServer.get_name() == "headless":
		return
	var rid: RID = root.get_viewport_rid()
	var cpu: float = RenderingServer.viewport_get_measured_render_time_cpu(rid) \
		+ RenderingServer.get_frame_setup_time_cpu()
	record.set_value(record.column("render_cpu_us"), roundi(cpu * 1000.0))
	record.set_value(record.column("gpu_us"), roundi(RenderingServer.viewport_get_measured_render_time_gpu(rid) * 1000.0))


func _book_memory() -> void:
	"""Memory and object counts, every frame (the monitors are cheap reads)."""
	record.set_value(record.column("static_kb"), roundi(Performance.get_monitor(Performance.MEMORY_STATIC) / 1024.0))
	record.set_value(record.column("nodes"), roundi(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
	record.set_value(record.column("objects"), roundi(Performance.get_monitor(Performance.OBJECT_COUNT)))
	record.set_value(record.column("video_kb"),
		roundi(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1024.0))
	record.set_value(record.column("draw_calls"),
		roundi(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))


func _lift_unasked_pause() -> void:
	"""A pause the plan did not ask for (a stall's diagnostic pause, a critical incident): count it and lift it."""
	if _manager.get_effective_speed() != 0:
		return
	unasked_pauses += 1
	_manager.acknowledge_overload()
	(village.get("_time") as Object).call(&"resume")
	if _manager.is_paused():
		_manager.resume_game()


func _follow_routes() -> void:
	"""Each resident's wait for a route: when it joins the desk's queue -- or its plan is the desk's job, carried over
	(route_desk.gd THE JOB, decision 1001) -- and how long until it leaves it. Read from the desk itself (O(residents) a
	frame; route_desk.gd keeps no wait times of its own)."""
	var desk: Object = _desk()
	var queue: PackedInt32Array = desk.get("_queue")
	var count: int = int(desk.get("_count"))
	_waiting_now.fill(0)
	for k: int in count:
		if queue[k] >= 0 and queue[k] < _waiting_now.size():
			_waiting_now[queue[k]] = 1
	var owner: int = int(desk.get("job_owner"))
	if owner >= 0 and owner < _waiting_now.size():
		_waiting_now[owner] = 1
	var now: int = virtual_usec
	for who: int in _wait_since.size():
		if _waiting_now[who] == 1 and _wait_since[who] < 0:
			_wait_since[who] = now
		elif _waiting_now[who] == 0 and _wait_since[who] >= 0:
			_waits.append(now - _wait_since[who])
			_wait_phase.append(_phase)
			_wait_since[who] = -1


func _follow_plans() -> void:
	"""The plans charged to each resident since the frame before (the desk's tally), booked by what it was doing: its
	task's script, an order to move, or its own routine. Plans charged to no resident (a formation's search) are not
	in it."""
	var desk: Object = _desk()
	var counts: PackedInt32Array = desk.get("plans_of")
	var usecs: PackedInt64Array = desk.get("plan_usec_of")
	var plans: int = 0
	var longest: int = 0
	for who: int in mini(counts.size(), _seen_plans.size()):
		var more: int = counts[who] - _seen_plans[who]
		if more <= 0:
			continue
		var spent: int = usecs[who] - _seen_plan_usec[who]
		_seen_plans[who] = counts[who]
		_seen_plan_usec[who] = usecs[who]
		plans += more
		longest = maxi(longest, spent)
		_book_plan(_plan_kind(who), more, spent)
	record.set_value(record.column("plans"), plans)
	record.set_value(record.column("plan_max_us"), longest)


func _plan_kind(who: int) -> String:
	"""What resident `who` was doing as it planned (see `_follow_plans`)."""
	var brain: Object = (_cast().call(&"actor", who) as Object).get("brain")
	var task: Object = brain.get("task")
	if task != null:
		return (task.get_script() as Script).resource_path.get_file().get_basename()
	var order_kind: int = int(brain.get("order"))
	return ORDER_KINDS[order_kind] if order_kind >= 0 and order_kind < ORDER_KINDS.size() else "order_%d" % order_kind


func _book_plan(kind: String, count: int, usec: int) -> void:
	"""Add `count` plans of `usec` to `kind`'s row."""
	var row: Array = plans_by_kind.get(kind, [0, 0, 0])
	plans_by_kind[kind] = [int(row[0]) + count, int(row[1]) + usec, maxi(int(row[2]), usec)]


func _steer() -> void:
	"""Move the plan on when its phase is done; ask for its speed again if the clock stepped it down."""
	if _manager.get_speed() != int(plan[_phase][1]):
		fallbacks += 1
		_manager.set_speed(int(plan[_phase][1]))
	if String(plan[_phase][0]) == "order":
		_steer_order()
		return
	if calendar_tick() >= int(plan[_phase][2]):
		_next_phase()


func _enter_phase(phase: int) -> void:
	"""Start phase `phase` at its speed (the order phase gives the order)."""
	_phase = phase
	var row: Array = plan[phase]
	_manager.set_speed(int(row[1]))
	print("SCALE phase %s at tick %d frame %d" % [row[0], calendar_tick(), _frame])
	if String(row[0]) == "order":
		_give_order()


func _next_phase() -> void:
	"""The next phase, or the end of the run."""
	if _phase + 1 < plan.size():
		_enter_phase(_phase + 1)
	else:
		_finish()


func _give_order() -> void:
	"""Order a work party -- the first ORDER_GROUP residents (all of them, when fewer) -- to stand in a formation on the
	village square, timing the call. A party the formation cannot fit (cast_orders.gd FORMATION_MAX_M, spaced for its
	widest body) is halved until one fits; the refused sizes are kept. Above ORDER_GROUP a whole-village order is tried
	first and only its call timed (an accepted one is released at once)."""
	var count: int = int(_cast().call(&"actor_count"))
	var spot: Vector3 = _order_spot()
	var everyone: Dictionary = {}
	if count > ORDER_GROUP:
		var before_all: int = Time.get_ticks_usec()
		var all_result: Dictionary = _cast().call(&"order_move", PackedInt32Array(range(count)), spot)
		everyone = {"members": count, "call_us": Time.get_ticks_usec() - before_all, "ok": bool(all_result.get("ok", false))}
		if everyone["ok"]:
			_cast().call(&"release", PackedInt32Array(range(count)))
	var party: int = mini(count, ORDER_GROUP)
	var result: Dictionary = {}
	var call_us: int = 0
	var refused: PackedInt32Array = PackedInt32Array()
	while party > 0:
		var before: int = Time.get_ticks_usec()
		result = _cast().call(&"order_move", PackedInt32Array(range(party)), spot)
		call_us = Time.get_ticks_usec() - before
		if bool(result.get("ok", false)):
			break
		refused.append(party)
		party >>= 1
	order = {"members": party, "call_us": call_us, "ok": bool(result.get("ok", false)), "refused_sizes": refused,
		"frame": _frame, "start_virtual_us": virtual_usec, "served_frame": -1, "served_frames": -1,
		"served_virtual_ms": -1, "spend_us": 0, "max_waiting": 0, "everyone": everyone}


func _order_spot() -> Vector3:
	"""The village square (the first spot when this world has none named so)."""
	var space: Object = _cast().call(&"space")
	var names: Array = space.get("poi_names")
	var spot: Vector2 = (space.get("poi_position") as PackedVector2Array)[maxi(names.find(&"square_west"), 0)]
	return Vector3(spot.x, 0.0, spot.y)


func _steer_order() -> void:
	"""Wait for the desk to serve the order (counting the spend), hold a moment, release everyone, go on."""
	var waiting: int = _desk().call(&"waiting")
	order["max_waiting"] = maxi(int(order["max_waiting"]), waiting)
	if int(order["served_frame"]) < 0:
		order["spend_us"] = int(order["spend_us"]) + probe.usec_of(&"cast.route_spend")
		if waiting == 0 and _frame > int(order["frame"]) + 1:
			order["served_frame"] = _frame
			order["served_frames"] = _frame - int(order["frame"])
			order["served_virtual_ms"] = roundi((virtual_usec - int(order["start_virtual_us"])) / 1000.0)
		elif _frame > int(order["frame"]) + ORDER_TIMEOUT_FRAMES:
			errors.append("the group order was not routed in %d frames" % ORDER_TIMEOUT_FRAMES)
			order["served_frame"] = _frame
		return
	if _frame >= int(order["served_frame"]) + ORDER_HOLD_FRAMES:
		_cast().call(&"release", PackedInt32Array(range(int(order["members"]))))
		_next_phase()


func _finish() -> void:
	"""Check the invariants, write the results and quit."""
	_quitting = true
	_manager.pause_game()
	errors.append_array(checks.run(village, residents))
	var report: Dictionary = ReportScript.build(self)
	if not out_path.is_empty():
		var file := FileAccess.open(out_path, FileAccess.WRITE)
		if file == null:
			errors.append("cannot write %s (paths are relative to godot/; give an absolute one)" % out_path)
		else:
			file.store_string(JSON.stringify(report, "\t"))
			file.close()
	if not csv_path.is_empty() and not record.write_csv(csv_path):
		errors.append("cannot write %s" % csv_path)
	ReportScript.print_summary(report)
	for line: String in errors:
		print("SCALE-ERROR %s" % line)
	print("SCALE-DONE %d %d %d" % [residents, record.row_count(), errors.size()])
	quit(1 if not errors.is_empty() else 0)


func _fail(why: String) -> void:
	"""Give up: say why and quit with 1."""
	_quitting = true
	print("SCALE-ERROR %s" % why)
	print("SCALE-DONE %d %d 1" % [residents, record.row_count()])
	quit(1)


func calendar_tick() -> int:
	"""The demo calendar's tick (0 is 06:00 of spring day 1)."""
	var services: Object = village.get("_services")
	return int((services.get("calendar") as Object).get("tick"))


func _cast() -> Node:
	"""The demo cast."""
	return village.get("_cast")


func _desk() -> Object:
	"""The cast's routing desk."""
	return (_cast().call(&"space") as Object).get("routes")


func behaviour() -> Dictionary:
	"""What the village did, beside what it cost: the kitchen's meals (who ate a portion, ate raw or went without) and
	how many residents have no bed tonight."""
	var kitchen: Object = (village.call(&"kitchen") as Object).get("kitchen")
	var night: Object = ((village.get("_command") as Object).call(&"tunnels") as Object).get("ext").get("night")
	var beds: PackedInt32Array = night.get("bed_of")
	return {"meal_keys": kitchen.get("meal_keys"), "meal_ate": kitchen.get("meal_ate"),
		"meal_raw": kitchen.get("meal_raw"), "meal_without": kitchen.get("meal_without"),
		"batches_cooked": kitchen.get("batches_cooked"), "portions_eaten": kitchen.get("portions_eaten"),
		"bedless": beds.count(-1), "residents": beds.size()}


func bursts() -> Array:
	"""The bursts reported apart (BURSTS)."""
	return BURSTS


func desk_counts() -> Dictionary:
	"""The routing desk's own counts over the run (route_desk.gd; decisions 1001-1002): plans served late, windows that
	ended with a plan carried over, the slices those plans took, the fields searched for shared goals, and the most a
	window spent."""
	var desk: Object = _desk()
	var worker: Object = desk.get("worker")
	return {"served": desk.get("served"), "jobs_carried": desk.get("jobs_carried"), "job_slices": desk.get("job_slices"),
		"fields_built": worker.get("fields_built"), "max_window_us": desk.get("max_window_usec")}


func route_waits_of(phase: int) -> PackedInt64Array:
	"""Every finished wait for a route in phase `phase`, microseconds."""
	var out := PackedInt64Array()
	for k: int in _waits.size():
		if _wait_phase[k] == phase:
			out.append(_waits[k])
	return out


func phase_name(phase: int) -> String:
	"""Phase `phase`'s name."""
	return String(plan[phase][0]) if phase >= 0 and phase < plan.size() else ""
