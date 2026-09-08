extends SceneTree
## Reproducible needs/work benchmark fixture.
##
## This is intentionally self-contained. It mirrors the small store setup in test_work.gd
## without importing the test suite, so benchmark results cannot depend on test discovery or
## assertion helpers. Invoke it with --path pointing at the project and --script pointing at
## this file; res:// preloads below are resolved from --path.
##
## Hash protocol: SHA-256 over UTF-8 canonical lines. Each line is
##   field|row|column|integer\n
## and rows/columns are emitted in ascending numeric order. The protocol includes needs and
## health values plus remainders, residents' skill XP, work and XP remainders, and each job's
## state and remaining milli-WU. It is deliberately explicit rather than using JSON so integer
## width and dictionary ordering cannot affect the digest.

const IntMath := preload("res://scripts/core/int_math.gd")
const NeedsScript := preload("res://scripts/core/needs.gd")
const ResidentsScript := preload("res://scripts/core/residents.gd")
const PrioritiesScript := preload("res://scripts/core/priorities.gd")
const ScheduleScript := preload("res://scripts/core/schedule.gd")
const JobsScript := preload("res://scripts/core/jobs.gd")
const WorkScript := preload("res://scripts/core/work.gd")

const HASH_PROTOCOL := "redwall-work-benchmark-v1/sha256/utf8-canonical-lines"
const HOUR_WORK: int = 8
const LONG_REMAINING_MWU: int = 1_000_000_000_000

var _args: Dictionary = {}
var _failure: String = ""
var _residents: ResidentsScript
var _needs: NeedsScript
var _priorities: PrioritiesScript
var _schedule: ScheduleScript
var _jobs: JobsScript
var _work: WorkScript
var _worker_slots: PackedInt32Array = PackedInt32Array()
var _job_slots: PackedInt32Array = PackedInt32Array()


func _initialize() -> void:
	var exit_code: int = _run()
	quit(exit_code)


func _run() -> int:
	_args = _parse_args(OS.get_cmdline_user_args())
	if _args.is_empty():
		return 1
	var config: String = str(_args["config"])
	var population: int = int(_args["population"])
	var warmup: int = int(_args["warmup"])
	var samples: int = int(_args["samples"])
	var output_path: String = str(_args["output"])
	if config != "needs" and config != "wu" and config != "combined":
		return _write_failure(output_path, "config must be needs, wu, or combined")
	if population != 12 and population != 256:
		return _write_failure(output_path, "population must be 12 or 256")
	if warmup < 0 or samples < 2:
		return _write_failure(output_path, "warmup must be >= 0 and samples must be >= 2")

	if not _setup(population):
		return _write_failure(output_path, _failure)
	var setup_hash: String = _state_hash()
	if _failure != "":
		return _write_failure(output_path, _failure)

	for tick: int in warmup:
		if not _tick_config(config):
			return _write_failure(output_path, "warmup tick %d: %s" % [tick, _failure])

	var durations_us: PackedInt64Array = PackedInt64Array()
	durations_us.resize(samples)
	for sample: int in samples:
		var started: int = Time.get_ticks_usec()
		if not _tick_config(config):
			return _write_failure(output_path, "sample tick %d: %s" % [sample, _failure])
		durations_us[sample] = Time.get_ticks_usec() - started

	if not _validate_live_rows():
		return _write_failure(output_path, _failure)
	var final_hash: String = _state_hash()
	if _failure != "":
		return _write_failure(output_path, _failure)
	var pair_durations_us: PackedInt64Array = PackedInt64Array()
	for pair: int in samples / 2:
		pair_durations_us.append(durations_us[pair * 2] + durations_us[pair * 2 + 1])
	var result: Dictionary = {
		"schema": "redwall-work-benchmark-v1",
		"hash_protocol": HASH_PROTOCOL,
		"config": config,
		"population": population,
		"warmup_ticks": warmup,
		"sample_ticks": samples,
		"pair_windows": pair_durations_us.size(),
		"setup_hash_sha256": setup_hash,
		"final_hash_sha256": final_hash,
		"p50_us": _nearest_rank(durations_us, 50),
		"p95_pair_us": _nearest_rank(pair_durations_us, 95),
		"p99_us": _nearest_rank(durations_us, 99),
		"total_sample_us": _sum(durations_us),
		"completed_jobs": 0,
		"all_jobs_remaining": true,
		"engine_version": Engine.get_version_info(),
	}
	return _write_result(output_path, result)


func _parse_args(user_args: PackedStringArray) -> Dictionary:
	var result: Dictionary = {}
	var index: int = 0
	while index < user_args.size():
		var key: String = user_args[index]
		if not key.begins_with("--") or index + 1 >= user_args.size():
			_failure = "arguments must be --key value pairs"
			return {}
		result[key.substr(2)] = user_args[index + 1]
		index += 2
	for required: String in ["config", "population", "warmup", "samples", "output"]:
		if not result.has(required):
			_failure = "missing --%s" % required
			return {}
	return result


func _setup(population: int) -> bool:
	_residents = ResidentsScript.new()
	_needs = _residents.needs()
	_priorities = PrioritiesScript.new()
	_schedule = ScheduleScript.new(_needs)
	_jobs = JobsScript.new(_residents, _priorities, _schedule)
	_work = WorkScript.new(_jobs)
	_worker_slots.resize(population)
	_job_slots.resize(population)
	for index: int in population:
		var spawned: ResidentsScript.OpResult = _residents.spawn(&"mouse")
		if not spawned.ok:
			return _fail("resident %d spawn refused: %s" % [index, spawned.error])
		var worker_slot: int = spawned.value
		_worker_slots[index] = worker_slot
		var priority_result: PrioritiesScript.OpResult = _priorities.spawn(worker_slot)
		if not priority_result.ok:
			return _fail("resident %d priorities refused: %s" % [index, priority_result.error])
		var template: IntMath.IntResult = _schedule.default_template_id()
		if not template.ok:
			return _fail("resident %d default schedule refused: %s" % [index, template.error])
		var schedule_result: ScheduleScript.OpResult = _schedule.spawn(worker_slot, template.value)
		if not schedule_result.ok:
			return _fail("resident %d schedule refused: %s" % [index, schedule_result.error])
		var resolve_result: IntMath.IntResult = _schedule.resolve(worker_slot, HOUR_WORK, false)
		if not resolve_result.ok:
			return _fail("resident %d schedule resolve refused: %s" % [index, resolve_result.error])
		var agent_result: JobsScript.OpResult = _jobs.spawn_agent(worker_slot)
		if not agent_result.ok:
			return _fail("resident %d agent refused: %s" % [index, agent_result.error])

		var created: JobsScript.OpResult = _jobs.create_job(
			JobsScript.JOB_KIND_KEEP, 0, 0, LONG_REMAINING_MWU, 0)
		if not created.ok:
			return _fail("resident %d job creation refused: %s" % [index, created.error])
		var job_slot: int = created.value
		_job_slots[index] = job_slot
		var bind_result: JobsScript.OpResult = _jobs.assign_worker(worker_slot, job_slot)
		if not bind_result.ok:
			return _fail("resident %d job binding refused: %s" % [index, bind_result.error])
		var state_result: JobsScript.OpResult = _jobs.set_state(job_slot, JobsScript.JOB_STATE_WORK)
		if not state_result.ok:
			return _fail("resident %d job state refused: %s" % [index, state_result.error])
	return _validate_setup(population)


func _validate_setup(population: int) -> bool:
	if _residents.population() != population or _residents.living_count() != population:
		return _fail("resident counts are not %d" % population)
	if _jobs.job_count() != population or _jobs.agent_count() != population:
		return _fail("job/agent counts are not %d" % population)
	for index: int in population:
		var worker: int = _worker_slots[index]
		var job: int = _job_slots[index]
		if not _residents.is_present(worker) or not _residents.is_alive(worker):
			return _fail("worker %d is not present and alive" % index)
		if not _jobs.is_agent_present(worker) or not _jobs.is_job_present(job):
			return _fail("worker %d job/agent row is missing" % index)
		var state: IntMath.IntResult = _jobs.state_of(job)
		var remaining: IntMath.IntResult = _jobs.remaining_mwu_of(job)
		if not state.ok or state.value != JobsScript.JOB_STATE_WORK:
			return _fail("worker %d job is not in WORK" % index)
		if not remaining.ok or remaining.value != LONG_REMAINING_MWU:
			return _fail("worker %d job has unexpected remaining work" % index)
		var worker_need: IntMath.IntResult = _needs.need_of(worker, 0)
		if not worker_need.ok or worker_need.value != NeedsScript.INITIAL_NEED_VALUE:
			return _fail("worker %d does not have default needs" % index)
	return true


func _tick_config(config: String) -> bool:
	if config == "needs" or config == "combined":
		var needs_result: NeedsScript.OpResult = _needs.tick_all()
		if not needs_result.ok:
			return _fail("needs tick refused: %s" % needs_result.error)
		if needs_result.value != _worker_slots.size():
			return _fail("needs tick integrated %d rows, expected %d" % [needs_result.value, _worker_slots.size()])
	if config == "needs":
		return true
	for index: int in _job_slots.size():
		var job: int = _job_slots[index]
		var tick_result: WorkScript.TickResult = _work.tick_solo(job)
		if not tick_result.ok:
			return _fail("work tick %d refused: %s" % [index, tick_result.error])
		if tick_result.completed or tick_result.accepted_mwu <= 0 or tick_result.remaining_mwu <= 0:
			return _fail("work tick %d violated productive non-completion outcome" % index)
	return true


func _validate_live_rows() -> bool:
	for index: int in _worker_slots.size():
		var worker: int = _worker_slots[index]
		var health: IntMath.IntResult = _needs.health_of(worker)
		if not health.ok or health.value <= 0:
			return _fail("worker %d health became invalid" % index)
		var remaining: IntMath.IntResult = _jobs.remaining_mwu_of(_job_slots[index])
		if not remaining.ok or remaining.value <= 0:
			return _fail("worker %d job completed unexpectedly" % index)
	return true


func _state_hash() -> String:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("protocol|%s\n" % HASH_PROTOCOL)
	for index: int in _worker_slots.size():
		var worker: int = _worker_slots[index]
		var health: IntMath.IntResult = _needs.health_of(worker)
		var health_remainder: IntMath.IntResult = _needs.health_remainder_of(worker)
		if not health.ok or not health_remainder.ok:
			_fail("hash health reader refused for worker %d" % index)
			return ""
		lines.append("health|%d|value|%d\n" % [index, health.value])
		lines.append("health|%d|remainder|%d\n" % [index, health_remainder.value])
		for need: int in NeedsScript.NEED_COUNT:
			var value: IntMath.IntResult = _needs.need_of(worker, need)
			var remainder: IntMath.IntResult = _needs.need_remainder_of(worker, need)
			if not value.ok or not remainder.ok:
				_fail("hash need reader refused for worker %d need %d" % [index, need])
				return ""
			lines.append("need|%d|%d|%d\n" % [index, need, value.value])
			lines.append("need_remainder|%d|%d|%d\n" % [index, need, remainder.value])
		var carry: IntMath.IntResult = _work.potential_remainder_of(worker)
		if not carry.ok:
			_fail("hash work carry reader refused for worker %d" % index)
			return ""
		lines.append("work_remainder|%d|value|%d\n" % [index, carry.value])
		for skill: int in ResidentsScript.SKILL_COUNT:
			var xp: IntMath.IntResult = _residents.skill_xp_of(worker, skill)
			if not xp.ok:
				_fail("hash skill XP reader refused for worker %d skill %d" % [index, skill])
				return ""
			lines.append("skill_xp|%d|%d|%d\n" % [index, skill, xp.value])
			var xp_remainder: IntMath.IntResult = _work.xp_remainder_of(worker, skill)
			if xp_remainder.ok:
				lines.append("xp_remainder|%d|%d|%d\n" % [index, skill, xp_remainder.value])
			elif skill == WorkScript.SKILL_RESERVED_INDEX and xp_remainder.error == String(WorkScript.REFUSE_RESERVED_SKILL):
				lines.append("xp_remainder|%d|%d|reserved\n" % [index, skill])
			else:
				_fail("unexpected XP remainder refusal")
				return ""
		var job: int = _job_slots[index]
		var state: IntMath.IntResult = _jobs.state_of(job)
		var remaining: IntMath.IntResult = _jobs.remaining_mwu_of(job)
		if not state.ok or not remaining.ok:
			_fail("hash job reader refused for worker %d" % index)
			return ""
		lines.append("job|%d|state|%d\n" % [index, state.value])
		lines.append("job|%d|remaining_mwu|%d\n" % [index, remaining.value])
	var hashing: HashingContext = HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update("".join(lines).to_utf8_buffer())
	return hashing.finish().hex_encode()


func _nearest_rank(values: PackedInt64Array, percentile: int) -> int:
	var ordered: Array[int] = []
	for value: int in values:
		ordered.append(value)
	ordered.sort()
	var rank: int = (percentile * ordered.size() + 99) / 100
	return ordered[rank - 1]


func _sum(values: PackedInt64Array) -> int:
	var total: int = 0
	for value: int in values:
		total += value
	return total


func _fail(message: String) -> bool:
	_failure = message
	return false


func _write_result(path: String, result: Dictionary) -> int:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		printerr("cannot open benchmark output: %s" % path)
		return 1
	file.store_string(JSON.stringify(result) + "\n")
	file.close()
	print("BENCHMARK_RESULT %s" % JSON.stringify(result))
	return 0


func _write_failure(path: String, message: String) -> int:
	var result: Dictionary = {
		"schema": "redwall-work-benchmark-v1",
		"hash_protocol": HASH_PROTOCOL,
		"ok": false,
		"error": message,
	}
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(result) + "\n")
		file.close()
	printerr("BENCHMARK_FAILURE %s" % message)
	return 1
