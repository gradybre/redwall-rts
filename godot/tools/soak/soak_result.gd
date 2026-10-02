extends RefCounted
## THE SOAK TEST'S RESULT (decision 0921): a finished (or failed) run reduced to one dictionary, written as JSON by the
## harness (soak_test.gd) and judged by tools/soak_report.py. Its keys:
##   meta      -- what the run was: residents, hours asked and run, fps, restarts asked, the harness's actions, the
##                engine, the display, wall time, frames, the counters (pauses lifted, 4x step-downs, orders);
##   hour_columns, hours -- the hourly table (soak_table.gd), one array of integers a game hour;
##   days      -- one record a game day: its frames' percentiles per column (soak_days.gd), its wall-clock span (unix
##                seconds, for the runner's load samples), and that day's pauses, step-downs, errors and warnings;
##   restarts  -- one record a restart: the monitors before and after, how long it took and what survived
##                (soak_leaks.gd);
##   exit      -- the same leak watch around freeing the village at the end (soak_test.gd THE END);
##   growth    -- the in-run growth check's verdicts (soak_growth.gd);
##   errors    -- the errors and warnings heard (soak_errors.gd);
##   failures  -- why the run failed (empty: it passed).


static func build(run: Object, growth: Array) -> Dictionary:
	"""The result of `run` (the harness, tools/soak/soak_test.gd) with the growth verdicts `growth`."""
	var table: Object = run.get("hours")
	return {"meta": meta(run), "hour_columns": Array(table.get("columns") as PackedStringArray),
		"hours": table.call(&"rows_as_arrays"), "hours_dropped": table.get("dropped"), "days": run.call(&"day_records"),
		"restarts": run.get("restart_records"), "exit": run.get("exit_record"), "growth": growth,
		"errors": (run.get("errors_heard") as Object).call(&"summary"), "failures": Array(run.get("failures"))}


static func meta(run: Object) -> Dictionary:
	"""What the run was and what it did (see the top)."""
	var ended: float = Time.get_unix_time_from_system()
	return {"residents_asked": run.get("residents"), "hours_asked": run.get("hours_asked"),
		"hours_run": run.get("soak_hour"), "fps": run.get("fps"),
		"speed": (run.get_script() as Script).get_script_constant_map().get("SPEED", 0),
		"restart_every_hours": run.get("restart_every_hours"), "stocked": run.get("stock"),
		"orders": run.get("give_orders"), "growth_skip_hours": run.get("growth_skip_hours"),
		"engine": Engine.get_version_info().get("string", ""), "debug_build": OS.is_debug_build(),
		"display": DisplayServer.get_name(), "started_unix": run.get("started_unix"), "ended_unix": ended,
		"wall_s": snappedf(ended - float(run.get("started_unix")), 0.1), "frames": run.get("frame"),
		"frames_run": run.get("frames_run"), "off_speed_frames": run.get("off_speed_frames"),
		"pauses_lifted": run.get("pauses_lifted"), "stall_lifts": run.get("stall_lifts"),
		"fallbacks": run.get("fallbacks"), "orders_given": run.get("orders_given"),
		"orders_refused": run.get("orders_refused"),
		"managed_nodes": (run.get("driver") as Object).call(&"managed_count")}
