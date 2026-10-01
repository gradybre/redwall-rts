extends RefCounted
## THE SCALE TEST'S RESULTS (decision 0561): a run's record reduced to one dictionary -- per phase, per burst, memory,
## the group order and the costliest scripts -- written as JSON by the harness and tabulated by tools/scale_test.py.
## Times are microseconds unless a key says ms; `work_us` is a frame's real duration (the run is uncapped, so that is
## all work: processing, physics, the render) less the harness's own time -- what a frame of the game costs without the
## measuring.

const RecordScript := preload("res://tools/scale_test/scale_record.gd")

const TOP_SCRIPTS: int = 20


static func build(run: Object) -> Dictionary:
	"""The report of a finished run (`run`: the harness, tools/scale_test/scale_test.gd)."""
	@warning_ignore("integer_division")
	var virtual_s: int = int(run.get("virtual_usec")) / 1000000
	var record: RecordScript = run.get("record")
	var plan: Array = run.get("plan")
	var report: Dictionary = {"residents": run.get("residents"), "fps": run.get("fps"),
		"display": DisplayServer.get_name(), "frames": record.row_count(), "unasked_pauses": run.get("unasked_pauses"),
		"fallbacks": run.get("fallbacks"), "plan": plan, "phase_speeds": _phase_speeds(record, plan.size()),
		"diagnostics": run.get("diagnostics"), "order": run.get("order"), "errors": run.get("errors"),
		"virtual_s": virtual_s,
		"managed_nodes": (run.get("driver") as Object).call(&"managed_count"), "phases": {}, "bursts": {}}
	var work: PackedInt64Array = _work_column(record)
	for phase: int in plan.size():
		var speed: int = int(plan[phase][1])
		var keep: Callable = func(row: int) -> bool: return record.value(row, record.column("phase")) == phase \
			and record.value(row, record.column("speed")) == speed
		var waits: PackedInt64Array = run.call(&"route_waits_of", phase)
		report["phases"][String(plan[phase][0])] = _section(record, work, keep, waits)
	for burst: Array in run.call(&"bursts"):
		var from: int = int(burst[1])
		var to: int = int(burst[2])
		var keep: Callable = func(row: int) -> bool:
			var tick: int = record.value(row, record.column("tick"))
			return tick >= from and tick < to and record.value(row, record.column("speed")) > 0
		report["bursts"][String(burst[0])] = _section(record, work, keep, PackedInt64Array())
	report["memory"] = _memory(record)
	report["behaviour"] = run.call(&"behaviour")
	report["stocked"] = run.get("stocked")
	report["plans_by_kind"] = run.get("plans_by_kind")
	report["off_poi_starts"] = run.get("off_poi_starts")
	report["scripts"] = _top_scripts((run.get("driver") as Object).call(&"script_totals"), record.row_count())
	return report


static func _work_column(record: RecordScript) -> PackedInt64Array:
	"""Each row's work: the frame's real duration less the harness's own time (see the top)."""
	var out := PackedInt64Array()
	out.resize(record.row_count())
	var frame: int = record.column("frame_us")
	var harness: int = record.column("harness_us")
	for row: int in record.row_count():
		out[row] = maxi(record.value(row, frame) - record.value(row, harness), 0)
	return out


static func _section(record: RecordScript, work: PackedInt64Array, keep: Callable,
		waits: PackedInt64Array) -> Dictionary:
	"""One phase's or burst's statistics: frame, work, GPU, every system and cast section, the speed it ran at."""
	var kept := PackedInt64Array()
	var rows := PackedInt32Array()
	var mask := PackedByteArray()
	mask.resize(record.row_count())
	for row: int in record.row_count():
		if keep.call(row):
			kept.append(work[row])
			rows.append(row)
			mask[row] = 1
	var only: Callable = func(row: int) -> bool: return mask[row] == 1
	var out: Dictionary = {"frames": rows.size(), "work_us": RecordScript.summary(kept), "systems": {}}
	for name: String in ["frame_us", "process_us", "gpu_us", "render_cpu_us", "harness_us", "scripts_us", "route_waiting",
			"plan_estimate_us", "plans", "plan_max_us", "walking"]:
		out[name] = record.stats(record.column(name), only)
	for k: int in record.columns.size():
		var column: String = record.columns[k]
		if column.begins_with("sys.") or column.begins_with("cast."):
			out["systems"][column] = record.stats(k, only)
	var engine := PackedInt64Array()
	for row: int in rows:
		engine.append(maxi(work[row] - record.value(row, record.column("scripts_us")), 0))
	out["engine_us"] = RecordScript.summary(engine)
	out["speeds"] = _speeds(record, rows)
	out["route_wait_us"] = RecordScript.summary(waits)
	return out


static func _phase_speeds(record: RecordScript, phases: int) -> Array:
	"""Per phase, how many frames ran at each effective speed (0: paused) -- the fallbacks included."""
	var out: Array = []
	for phase: int in phases:
		var rows := PackedInt32Array()
		for row: int in record.row_count():
			if record.value(row, record.column("phase")) == phase:
				rows.append(row)
		out.append(_speeds(record, rows))
	return out


static func _speeds(record: RecordScript, rows: PackedInt32Array) -> Dictionary:
	"""How many of these frames ran at each effective speed (0: paused)."""
	var out: Dictionary = {}
	var at: int = record.column("speed")
	for row: int in rows:
		var speed: String = str(record.value(row, at))
		out[speed] = int(out.get(speed, 0)) + 1
	return out


static func _memory(record: RecordScript) -> Dictionary:
	"""Static memory, nodes, objects and video memory: at the first row, the last and the most."""
	var out: Dictionary = {}
	var last: int = record.row_count() - 1
	for name: String in ["static_kb", "nodes", "objects", "video_kb", "draw_calls"]:
		var at: int = record.column(name)
		var most: int = 0
		for row: int in record.row_count():
			most = maxi(most, record.value(row, at))
		out[name] = {"first": record.value(0, at) if last >= 0 else 0, "last": record.value(last, at) if last >= 0 else 0,
			"max": most}
	return out


static func _top_scripts(script_usec: Dictionary, frames: int) -> Array:
	"""The TOP_SCRIPTS scripts by their whole-run time: [path, total ms, mean us a frame]."""
	var rows: Array = []
	for path: String in script_usec:
		rows.append([path, int(script_usec[path])])
	rows.sort_custom(func(a: Array, b: Array) -> bool: return int(a[1]) > int(b[1]))
	var out: Array = []
	for row: Array in rows.slice(0, TOP_SCRIPTS):
		@warning_ignore("integer_division")
		out.append([row[0], int(row[1]) / 1000, int(row[1]) / maxi(frames, 1)])
	return out


static func print_summary(report: Dictionary) -> void:
	"""One SCALE line per phase and burst: frame and work p50/p95/p99, the top systems by mean."""
	for group: String in ["phases", "bursts"]:
		for name: String in report[group]:
			var section: Dictionary = report[group][name]
			var work: Dictionary = section["work_us"]
			print("SCALE %s %s frames=%d work_us p50=%d p95=%d p99=%d max=%d process_p95=%d speeds=%s" % [group, name,
				section["frames"], work["p50"], work["p95"], work["p99"], work["max"], section["process_us"]["p95"],
				section["speeds"]])
	var memory: Dictionary = report["memory"]
	print("SCALE memory static_kb=%s nodes=%s objects=%s" % [memory["static_kb"], memory["nodes"], memory["objects"]])
	print("SCALE order %s" % report["order"])
	print("SCALE unasked_pauses %d diagnostics %d" % [report["unasked_pauses"], (report["diagnostics"] as Array).size()])
