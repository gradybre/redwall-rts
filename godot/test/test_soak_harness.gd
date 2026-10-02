extends "res://test/framework/test_case.gd"
## The soak test (godot/tools/soak/, decision 0921): its hourly table and per-day frame buffers, the in-run growth
## check, the restart leak watch on hand-built object graphs (a cycle, a held object, a static cache, a freed one), the
## error counter -- and the real village in its own process: five game hours with a Restart demo (about 20 s), and, only
## with REDWALL_SLOW_TESTS=1, ONE GAME DAY with a restart, asserting it finished with no error, nothing of the first
## village left unreachable and no growth beyond the in-run tolerances (soak_growth.gd). The day is about 45 s on an
## idle machine; the suite skips it otherwise, as test_balance_harness.gd's season run (decision 0911).

const TableScript := preload("res://tools/soak/soak_table.gd")
const DaysScript := preload("res://tools/soak/soak_days.gd")
const GrowthScript := preload("res://tools/soak/soak_growth.gd")
const LeaksScript := preload("res://tools/soak/soak_leaks.gd")
const ErrorsScript := preload("res://tools/soak/soak_errors.gd")
const ResultScript := preload("res://tools/soak/soak_result.gd")

const HARNESS: String = "res://tools/soak/soak_test.gd"
const SLOW_ENV: String = "REDWALL_SLOW_TESTS"
const SLOW_LIMIT_MSEC: int = 1200000


## A node of the graphs the leak watch walks: one strong reference out, and a list.
class Pal extends RefCounted:
	var other: RefCounted = null
	var many: Array = []


## A script whose static member holds what it caches (as forest_root_field.gd's baked fields).
class Cache extends RefCounted:
	static var kept: Array = []


## A node holding a Pal, and a spare.
class Holder extends Node:
	var pal: RefCounted = null
	var spare: RefCounted = null


func test_the_table_keeps_rows_up_to_its_capacity() -> void:
	"""Rows land in order; past the capacity a row is dropped and counted, never grown into."""
	var table := TableScript.new()
	table.setup(PackedStringArray(["a", "b"]), 2)
	for k: int in 3:
		table.set_value(table.column("a"), k)
		table.set_value(table.column("b"), 10 * k)
		table.set_value(table.column("nope"), 99)
		table.commit()
	assert_equal([table.row_count(), table.capacity(), table.dropped], [2, 2, 1], "two kept, one dropped")
	assert_equal([table.value(1, 0), table.value(1, 1), table.column("nope")], [1, 10, -1], "values and columns")
	assert_equal(table.series(1), PackedInt64Array([0, 10]), "a column's series")
	assert_equal(table.rows_as_arrays(), [[0, 0], [1, 10]], "rows for the JSON")


func test_a_day_of_frames_reduces_to_percentiles_and_starts_again() -> void:
	"""A day's frames give nearest-rank percentiles per column; past the capacity they are counted, not kept; the next
	day starts empty; past the days' capacity a day is not kept."""
	var days := DaysScript.new()
	days.setup(PackedStringArray(["work_us", "sys.x"]), 100, 2)
	for k: int in 101:
		days.set_value(0, k + 1)
		days.set_value(1, 7)
		days.set_value(5, 1)
		days.commit()
	assert_equal(days.close_day(), 0, "the first day kept")
	var day: Dictionary = days.summary_of(0)
	var work: Dictionary = day["columns"]["work_us"]
	assert_equal([day["frames"], day["dropped"], work["p50"], work["p95"], work["max"]], [100, 1, 50, 95, 100],
		"100 kept, one dropped, ranked")
	assert_equal(day["columns"]["sys.x"]["mean"], 7, "a system's mean")
	assert_equal(days.frames(), 0, "the next day starts empty")
	assert_equal(days.close_day(), 1, "the second day kept")
	assert_equal(days.summary_of(1)["columns"]["work_us"]["n"], 0, "an empty day is all zeros")
	assert_equal([days.close_day(), days.days_kept()], [-1, 2], "a third is past the capacity: not kept")
	assert_equal(days.summary_of(0)["columns"]["work_us"]["p99"], 99, "the first day is still as it was")


func test_a_frame_value_is_clamped_to_int32() -> void:
	"""A frame longer than int32 microseconds (never, but a stuck clock) is clamped, not wrapped."""
	var days := DaysScript.new()
	days.setup(PackedStringArray(["work_us"]), 4)
	days.set_value(0, 1 << 40)
	days.commit()
	assert_equal(days.summary_of(days.close_day())["columns"]["work_us"]["max"], 2147483647, "clamped")


func test_the_slope_and_the_rising_share() -> void:
	"""A straight line's slope; a flat series 0; the share of steps that went up."""
	assert_almost_equal(GrowthScript.slope(PackedInt64Array([1, 3, 5, 7])), 2.0, "2 a step")
	assert_almost_equal(GrowthScript.slope(PackedInt64Array([4, 4, 4])), 0.0, "flat")
	assert_almost_equal(GrowthScript.slope(PackedInt64Array([4])), 0.0, "one point")
	assert_almost_equal(GrowthScript.rising_share(PackedInt64Array([1, 2, 2, 3, 1])), 0.5, "two of four up")
	assert_almost_equal(GrowthScript.rising_share(PackedInt64Array()), 0.0, "none")


func test_growth_fails_only_on_a_rise_over_its_tolerance_both_ways() -> void:
	"""A steady rise of 2 an hour is 48 a day: over a tolerance of 24 it fails, under 100 it passes; noise round a flat
	line passes; one late jump with a small net change passes."""
	var rising := PackedInt64Array()
	for k: int in 25:
		rising.append(1000 + 2 * k)
	assert_true(bool(GrowthScript.judge("x", rising, 24.0)["fail"]), "48 a day over 24 fails")
	assert_false(bool(GrowthScript.judge("x", rising, 100.0)["fail"]), "under 100 passes")
	assert_equal(GrowthScript.judge("x", rising, 24.0)["net"], 48, "the net change")
	var noisy := PackedInt64Array([1000, 1003, 998, 1002, 999, 1001, 1000, 1002, 998, 1001])
	assert_false(bool(GrowthScript.judge("x", noisy, 24.0)["fail"]), "noise passes")
	var jump := PackedInt64Array([1000, 1000, 1000, 1000, 1000, 1000, 1020])
	assert_false(bool(GrowthScript.judge("x", jump, 24.0)["fail"]), "a small late step: net 20 within a day's 24")


func test_the_check_reads_every_tolerance_column_after_the_skip() -> void:
	"""The check judges each TOLERANCES column the table has, from the skipped row on, and names each failure."""
	var table := TableScript.new()
	table.setup(PackedStringArray(["objects", "nodes"]), 30)
	for k: int in 30:
		table.set_value(0, 100000 if k < 5 else 13000 + 50 * k)
		table.set_value(1, 3600)
		table.commit()
	var verdicts: Array = GrowthScript.check(table, 5)
	assert_equal(verdicts.size(), 2, "objects and nodes (the table has no others)")
	assert_equal([verdicts[0]["column"], verdicts[0]["samples"], verdicts[0]["fail"]], ["objects", 25, true],
		"objects rise 1200 a day past the skip (the 100000 warm-up rows skipped)")
	assert_false(bool(verdicts[1]["fail"]), "nodes flat")
	var lines: PackedStringArray = GrowthScript.failures(verdicts)
	assert_true(lines.size() == 1 and lines[0].begins_with("objects grew"), "one failure line: %s" % lines)


func test_the_leak_watch_finds_a_cycle_and_spares_what_is_freed_or_held() -> void:
	"""A 'village' holding a two-object cycle (which holds two more, a Resource and a Callable on an object), a spare,
	and objects an outside node also holds: once the village is freed the spare is gone, the cycle and what it holds
	are unreachable, the shared ones held; a Resource is never watched."""
	var keeper := Holder.new()
	var village: Holder = _village_with_a_cycle(keeper)
	var leaks := LeaksScript.new()
	assert_equal(leaks.watch(village), 8, "the village, the cycle, its three objects, one reached by a Callable and the \
		spare (not the Resource)")
	var cycle: WeakRef = weakref(village.pal)
	village.free()
	var out: Dictionary = leaks.check(keeper)
	assert_equal([out["survivors"], out["unreachable"], out["held"]], [6, 4, 2], "spare freed; 4 unreachable; 2 held")
	assert_equal(out["unreachable_by_label"].values().reduce(func(a: int, b: int) -> int: return a + b, 0), 4,
		"labelled")
	var a: Pal = cycle.get_ref()
	if a != null:
		a.other = null
		a.many.clear()
	keeper.free()


func _village_with_a_cycle(keeper: Holder) -> Holder:
	"""The graph of the test above; its locals die here, so only the village and `keeper` hold it."""
	var village := Holder.new()
	var a := Pal.new()
	var b := Pal.new()
	a.other = b
	b.other = a
	var shared := Pal.new()
	keeper.pal = shared
	var by_call := Pal.new()
	keeper.spare = by_call
	a.many = [Pal.new(), shared, Cache.new(), Resource.new(), Callable(by_call, &"get_class")]
	village.pal = a
	village.spare = Pal.new()
	return village


func test_an_object_its_own_script_caches_is_held() -> void:
	"""An object only its script's static member still holds (as forest_root_field.gd's baked fields) is held, not
	leaked."""
	var village := Holder.new()
	Cache.kept = [Cache.new()]
	village.pal = Cache.kept[0]
	var leaks := LeaksScript.new()
	assert_equal(leaks.watch(village), 2, "the village and the cached object")
	village.free()
	var root := Holder.new()
	var out: Dictionary = leaks.check(root)
	assert_equal([out["survivors"], out["held"], out["unreachable"]], [1, 1, 0], "held by the static, not leaked")
	root.free()
	Cache.kept = []


func test_a_static_member_met_on_the_way_holds_too() -> void:
	"""An old object only a STATIC member of some live object's script holds (not its own script's) is held."""
	var village := Holder.new()
	var survivor := Pal.new()
	Cache.kept = [survivor]
	village.pal = survivor
	survivor = null
	var leaks := LeaksScript.new()
	assert_equal(leaks.watch(village), 2, "the village and the Pal")
	village.free()
	var root := Holder.new()
	root.pal = Cache.new()
	var out: Dictionary = leaks.check(root)
	assert_equal([out["survivors"], out["held"]], [1, 1], "held through Cache's static, met on the way from the root")
	root.free()
	Cache.kept = []


func test_labels_name_a_script_file_or_a_class() -> void:
	"""A scripted object by its file, a plain one by its class, a node says so."""
	assert_equal(LeaksScript.label_of(TableScript.new()), "soak_table.gd", "a script's file")
	assert_equal(LeaksScript.label_of(RefCounted.new()), "RefCounted", "a class")
	var node := Node.new()
	assert_equal(LeaksScript.label_of(node), "node Node", "a node")
	node.free()


func test_the_error_counter_counts_by_kind_and_keeps_the_first_few() -> void:
	"""Errors and script errors count as errors, warnings apart; only the first KEEP of each are kept word for word."""
	var heard := ErrorsScript.new()
	var trace: Array[ScriptBacktrace] = []
	for k: int in ErrorsScript.KEEP + 2:
		heard._log_error("f", "res://x.gd", k, "code", "why %d" % k, false, Logger.ERROR_TYPE_ERROR, trace)
	heard._log_error("g", "res://y.gd", 1, "c", "", false, Logger.ERROR_TYPE_SCRIPT, trace)
	heard._log_error("h", "res://z.gd", 2, "c", "careful", false, Logger.ERROR_TYPE_WARNING, trace)
	var out: Dictionary = heard.summary()
	assert_equal([heard.errors(), heard.warnings()], [ErrorsScript.KEEP + 3, 1], "counted by kind")
	assert_equal((out["first_errors"] as PackedStringArray).size(), ErrorsScript.KEEP, "only the first KEEP kept")
	assert_true(String(out["first_errors"][0]).begins_with("ERROR: why 0 (res://x.gd:0 f)"), "worded with its place")
	assert_true(String(out["first_warnings"][0]).begins_with("careful"), "a warning's text")


func test_the_harness_reads_its_arguments() -> void:
	"""Days or hours, restarts, fps, the out path and the switches (the harness's own parser, no village booted)."""
	var run: Object = (load(HARNESS) as GDScript).new()
	run.call(&"_read_args", PackedStringArray(["--days", "3", "--residents", "25", "--restart-every-hours", "12",
		"--fps", "30", "--out", "/tmp/x.json", "--no-stock", "--growth-skip-hours", "6"]))
	assert_equal([run.get("hours_asked"), run.get("residents"), run.get("restart_every_hours"), run.get("fps"),
		run.get("out_path"), run.get("stock"), run.get("give_orders"), run.get("growth_skip_hours")],
		[72, 25, 12, 30, "/tmp/x.json", false, true, 6], "parsed")
	run.call(&"_read_args", PackedStringArray(["--hours", "5", "--residents", "999"]))
	assert_equal([run.get("hours_asked"), run.get("residents")], [5, 256], "hours win; residents capped at 256")
	var driver: Node = run.get("driver")
	(driver.get("_end") as Node).free()
	driver.free()
	run.free()


func test_a_few_hours_with_a_restart_leave_nothing_behind() -> void:
	"""The real village for five game hours at 4x with Restart demo at the fourth (the kitchen has cooked by then): it
	finishes, hears no error and leaves nothing of the first village unreachable. About 20 s; the growth check needs
	the slow day below."""
	var out: String = OS.get_temp_dir().path_join("soak_suite_hours.json")
	var code: int = _soak(["--hours", "5", "--restart-every-hours", "4", "--growth-skip-hours", "5"], out)
	_assert_soak_json(out, 6, 0)
	assert_equal(code, 0, "exit 0")


func test_one_game_day_with_a_restart_has_no_errors_leaks_or_growth() -> void:
	"""SLOW (REDWALL_SLOW_TESTS=1): one game day of the real village at 4x, Restart demo at midnight after the first
	supper (game hour 18 of the run); the run finishes, hears no error, leaves nothing unreachable, and from the first
	evening on (hour 13: the first supper's one-time allocations are warm-up) grows within the short-run tolerances.
	About 45 s on an idle machine."""
	if OS.get_environment(SLOW_ENV) != "1":
		assert_true(true, "skipped")
		print("test_soak_harness: the one-day soak run is skipped (set %s=1)" % SLOW_ENV)
		return
	var out: String = OS.get_temp_dir().path_join("soak_suite_day.json")
	var started: int = Time.get_ticks_msec()
	var code: int = _soak(["--hours", "24", "--restart-every-hours", "18", "--growth-skip-hours", "13"], out)
	assert_less_than(float(Time.get_ticks_msec() - started), float(SLOW_LIMIT_MSEC), "within the slow limit")
	_assert_soak_json(out, 25, 1)
	assert_equal(code, 0, "exit 0")


func _soak(run_args: Array[String], out: String) -> int:
	"""Run the harness in its own process with `run_args` into `out`; assert on its printed lines; its exit code."""
	DirAccess.remove_absolute(out)
	var args: PackedStringArray = ["--headless", "--fixed-fps", "60", "--path", ProjectSettings.globalize_path("res://"),
		"--script", HARNESS, "--"]
	args.append_array(run_args)
	args.append_array(["--out", out])
	var output: Array = []
	var code: int = OS.execute(OS.get_executable_path(), args, output, true, false)
	_assert_soak_output(("".join(PackedStringArray(output))).split("\n"), int(run_args[1]))
	return code


func _assert_soak_output(lines: PackedStringArray, hours: int) -> void:
	"""The run's printed lines: SOAK-DONE `hours`, 0 errors, 0 failures, and no SOAK-FAIL or script error."""
	var done: String = ""
	for line: String in lines:
		if line.begins_with("SOAK-DONE "):
			done = line
		elif line.begins_with("SOAK-FAIL") or line.contains("SCRIPT ERROR"):
			fail("the soak run printed: %s" % line)
	assert_equal(done, "SOAK-DONE %d 0 0" % hours, "%d game hours, no errors, no failures" % hours)


func _assert_soak_json(path: String, rows: int, days: int) -> void:
	"""The JSON: `rows` hourly rows, `days` days, one restart that left nothing unreachable, no error heard."""
	var result: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert_true(result is Dictionary, "the JSON was written")
	if not result is Dictionary:
		return
	assert_equal([(result["hours"] as Array).size(), (result["days"] as Array).size(),
		(result["restarts"] as Array).size()], [rows, days, 1], "hours, days, one restart")
	assert_equal(int(result["restarts"][0]["leaks"]["unreachable"]), 0, "nothing of the first village unreachable")
	assert_equal(int(result["exit"]["leaks"]["unreachable"]), 0, "nor of the last, freed at the end")
	assert_true(int(result["exit"]["watched"]) > 1000, "the last village was watched")
	assert_equal(int(result["errors"]["errors"]), 0, "no errors heard")
