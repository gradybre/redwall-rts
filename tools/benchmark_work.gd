extends SceneTree
## Reproducible needs/work benchmark fixture, with per-part probes and adversarial workloads.
##
## This is intentionally self-contained. It mirrors the small store setup in test_work.gd
## without importing the test suite, so benchmark results cannot depend on test discovery or
## assertion helpers. Invoke it with --path pointing at the project and --script pointing at
## this file; res:// preloads below are resolved from --path.
##
## ---------------------------------------------------------------------------------------
## WHAT A PROBE CONFIG MEASURES, AND WHAT IT DOES NOT.
##
## The `loop`, `pid`, `xp` and `result` configs each run ONE named part of the productive
## work-unit tick over the same contributor set, in the same loop shape, and nothing else.
## They are RUNNING LESS WORK, not partitioning the whole tick:
##   * every probe pays the same per-iteration loop floor, which `loop` measures on its own so
##     it can be stated rather than assumed;
##   * probe costs OVERLAP -- the floor is inside all of them -- so they do not sum to `wu`;
##   * probe costs OMIT INTERACTION -- instruction cache pressure, the branch history the rest
##     of the tick creates, and the allocator state a full tick leaves behind are all absent.
## A probe therefore establishes THE COST OF RUNNING THAT PART IN ISOLATION. It does not
## establish that removing that part from the full tick recovers that many microseconds, and
## no arithmetic performed on these numbers can turn measurement into causation.
##
## ---------------------------------------------------------------------------------------
## BENCHMARK ARTIFACTS. Every fixture input below that is a choice of this harness rather than
## a value fixed by the GDD, decision 0017 or decision 0022 is named in BENCHMARK_ARTIFACTS and
## is reported inside the result JSON. Nothing here is a balance constant and nothing here may
## be read back into the spec.
##
## ---------------------------------------------------------------------------------------
## Hash protocol: SHA-256 over UTF-8 canonical lines. Each line is
##   field|row|column|integer\n
## and rows/columns are emitted in ascending numeric order. The protocol includes needs and
## health values plus remainders, residents' skill XP, work and XP remainders, and each job's
## state and remaining milli-WU. It is deliberately explicit rather than using JSON so integer
## width and dictionary ordering cannot affect the digest.
##
## ---------------------------------------------------------------------------------------
## WHICH TICK ENTRY POINT THE `wu`, `party_fast` AND `party_finish` CONFIGS CALL. They call
## decision 0024 section 2's `tick_solo_into()` / `tick_party_into()` with ONE caller-owned
## `TickResult` allocated at fixture construction, which is the form a simulation caller is
## required to use. The earlier fixture called the allocating `tick_solo()` / `tick_party()`
## wrappers, so a before/after release comparison of those three configs is a comparison of two
## fixture revisions as well as two `work.gd` revisions -- THE CALL SITE IS PART OF THE CHANGE
## BEING MEASURED, and the driver's `fixture_sha256` will differ between the two sides for that
## reason and no other.
##
## `_tick_needs()` IS BYTE-IDENTICAL ACROSS THAT CHANGE and touches `work.gd` not at all, so the
## `needs` config remains a valid same-session drift control on both sides. So does `result`,
## whose probe body still builds one escaping TickResult per contributor exactly as before.
##
## THE PROTOCOL NAME IS UNCHANGED AND THE `uniform` WORKLOAD EMITS THE v1 LINE SET BYTE FOR
## BYTE, so its digests are directly comparable with the ones committed under
## validation-results/work-readers-2026-09-07/. A workload that owns coordinator rows appends
## `coordinator|...` lines after the per-worker lines; a workload with no coordinator rows
## appends none, so v1 compatibility is a property of the rows present, not of a version flag.
## `hash_lines` is reported so the line count of any run can be checked against that claim.

const IntMath := preload("res://scripts/core/int_math.gd")
const NeedsScript := preload("res://scripts/core/needs.gd")
const ResidentsScript := preload("res://scripts/core/residents.gd")
const PrioritiesScript := preload("res://scripts/core/priorities.gd")
const ScheduleScript := preload("res://scripts/core/schedule.gd")
const JobsScript := preload("res://scripts/core/jobs.gd")
const WorkScript := preload("res://scripts/core/work.gd")

const HASH_PROTOCOL := "redwall-work-benchmark-v1/sha256/utf8-canonical-lines"
const HOUR_WORK: int = 8

# --- benchmark artifacts, not spec values -------------------------------------------------------
## A job total large enough that no sampled tick can finish it. Chosen by this harness.
const LONG_REMAINING_MWU: int = 1_000_000_000_000
## The outstanding work a `party_finish` tick is reset to, so acceptance is strictly below the
## party's summed potential and decision 0017's proportional split and leftover pass both run.
## Small and coprime with common party sizes so the leftover pass is at its worst case.
const PARTY_FINISH_MWU: int = 7
## `work.set_memory_total()` inputs that place a resident whose needs are all at the spawn
## default in each of §5.2's five mood bands. Mood is `floor(weighted needs/10) + memory_total`,
## and the spawn default gives 7500, so these offsets land 1999 / 3500 / 5500 / 7500 / 9500.
## THEY ARE NOT MoodMemory SUMS: no MoodMemory store exists (blocker U6).
const MEMORY_TOTAL_BY_MOOD_BAND: Array[int] = [-5501, -4000, -2000, 0, 2000]
## Health values placing a resident in each of §5.2's three health bands, with enough margin
## that the +2/hour recovery cannot move one across a band floor inside a sampled run.
const HEALTH_BY_BAND: Array[int] = [30, 55, 100]
## Party sizes cycled across the residents of the `party` workload.
const PARTY_SIZES: Array[int] = [1, 2, 3, 4, 5, 6, 7, 8]
## Strides used to walk the job-kind and skill-level tables, so neighbouring residents differ.
const KIND_STRIDE: int = 5
const SKILL_LEVEL_STRIDE: int = 7

const CONFIGS: Array[String] = ["needs", "wu", "combined", "loop", "pid", "xp", "result",
	"factor", "gate", "party_fast", "party_finish"]
const WORKLOADS: Array[String] = ["uniform", "bands", "party"]
const PARTY_ONLY_CONFIGS: Array[String] = ["party_fast", "party_finish"]

var _args: Dictionary = {}
var _failure: String = ""
var _residents: ResidentsScript
var _needs: NeedsScript
var _priorities: PrioritiesScript
var _schedule: ScheduleScript
var _jobs: JobsScript
var _work: WorkScript

## One entry per worker. `_worker_job` is the row that worker is bound to: its own solo job in
## the `uniform`/`bands` workloads, its member job in `party`.
var _worker_slots: PackedInt32Array = PackedInt32Array()
var _worker_job: PackedInt32Array = PackedInt32Array()
var _worker_skill: PackedInt32Array = PackedInt32Array()
## The REQ-SET-020 memory total supplied to each worker, held here so the factor probe can pass
## `mood_into()` the same integer `work._compute_factor()` reads from its own column, without a
## convenience reader's allocation appearing inside a probe that is not about allocation.
var _worker_memory: PackedInt32Array = PackedInt32Array()
## The rows a productive tick is issued against, and which hold the authoritative outstanding
## work: the solo jobs, or the coordinators of the `party` workload.
var _progress_slots: PackedInt32Array = PackedInt32Array()
var _is_party: bool = false
var _kind_cycle: PackedInt32Array = PackedInt32Array()
var _hash_lines: int = 0
var _factor_sum: int = 0
var _factor_min: int = 0
var _factor_max: int = 0
## Probe scratch, allocated once so a probe measures the part it names and not an allocation
## this fixture added.
var _probe_accumulator: int = 0
var _probe_math: IntMath.IntResult = IntMath.IntResult.new()
## The caller-owned result the `wu`, `party_fast` and `party_finish` configs tick into
## (decision 0024 section 2). Allocated once here, at fixture construction and outside every
## timed region, so the sampled tick allocates no result at all. Its contents are read and
## finished with before the next tick overwrites them, which is the one usage pattern a single
## shared result is correct for -- nothing in this fixture retains a tick outcome.
var _tick_result: WorkScript.TickResult = WorkScript.TickResult.new(false,
	WorkScript.REFUSE_NONE)


func _initialize() -> void:
	var exit_code: int = _run()
	quit(exit_code)


func _run() -> int:
	"""Parse, set up, sample, validate and write one benchmark result. Returns a process code."""
	_args = _parse_args(OS.get_cmdline_user_args())
	if _args.is_empty():
		printerr("BENCHMARK_FAILURE %s" % _failure)
		return 1
	var config: String = str(_args["config"])
	var workload: String = str(_args["workload"])
	var population: int = int(_args["population"])
	var warmup: int = int(_args["warmup"])
	var samples: int = int(_args["samples"])
	var output_path: String = str(_args["output"])
	var objection: String = _argument_objection(config, workload, population, warmup, samples)
	if objection != "":
		return _write_failure(output_path, objection)
	if not _setup(population, workload):
		return _write_failure(output_path, _failure)
	return _measure(config, workload, population, warmup, samples, output_path)


func _measure(config: String, workload: String, population: int, warmup: int, samples: int,
		output_path: String) -> int:
	"""Digest the built fixture, time the sampled ticks, revalidate and write the result."""
	var setup_hash: String = _state_hash()
	if _failure != "":
		return _write_failure(output_path, _failure)
	var durations_us: PackedInt64Array = PackedInt64Array()
	durations_us.resize(samples)
	if not _sample(config, warmup, samples, durations_us):
		return _write_failure(output_path, _failure)
	if not _validate_after(config):
		return _write_failure(output_path, _failure)
	var final_hash: String = _state_hash()
	if _failure != "":
		return _write_failure(output_path, _failure)
	return _write_result(output_path,
		_summary(config, workload, population, warmup, samples, durations_us,
			setup_hash, final_hash))


func _parse_args(user_args: PackedStringArray) -> Dictionary:
	"""Read `--key value` pairs into a dictionary, refusing anything else explicitly."""
	var result: Dictionary = {}
	var index: int = 0
	while index < user_args.size():
		var key: String = user_args[index]
		if not key.begins_with("--") or index + 1 >= user_args.size():
			_failure = "arguments must be --key value pairs"
			return {}
		result[key.substr(2)] = user_args[index + 1]
		index += 2
	for required: String in ["config", "workload", "population", "warmup", "samples", "output"]:
		if not result.has(required):
			_failure = "missing --%s" % required
			return {}
	return result


func _argument_objection(config: String, workload: String, population: int, warmup: int,
		samples: int) -> String:
	"""The reason these arguments are unusable, or an empty string when they are all in domain."""
	if not CONFIGS.has(config):
		return "config must be one of %s" % str(CONFIGS)
	if not WORKLOADS.has(workload):
		return "workload must be one of %s" % str(WORKLOADS)
	if PARTY_ONLY_CONFIGS.has(config) and workload != "party":
		return "config %s requires --workload party" % config
	if population != 12 and population != 256:
		return "population must be 12 or 256"
	if warmup < 0 or samples < 2:
		return "warmup must be >= 0 and samples must be >= 2"
	return ""


# --- fixture construction ------------------------------------------------------------------------

func _setup(population: int, workload: String) -> bool:
	"""Build the stores, the residents and the jobs this workload measures."""
	_residents = ResidentsScript.new()
	_needs = _residents.needs()
	_priorities = PrioritiesScript.new()
	_schedule = ScheduleScript.new(_needs)
	_jobs = JobsScript.new(_residents, _priorities, _schedule)
	_work = WorkScript.new(_jobs)
	_is_party = workload == "party"
	_fill_kind_cycle()
	_worker_slots.resize(population)
	_worker_job.resize(population)
	_worker_skill.resize(population)
	_worker_memory.resize(population)
	for index: int in population:
		if not _spawn_worker(index, workload):
			return false
	if not _create_jobs(population, workload):
		return false
	return _validate_setup(population) and _record_factors(population)


func _fill_kind_cycle() -> void:
	"""List the productive job kinds, skipping decision 0022's reserved kind rather than naming
	the catalog indices again here."""
	_kind_cycle.resize(0)
	for kind: int in JobsScript.JOB_KIND_COUNT:
		if kind != JobsScript.JOB_KIND_RESERVED_INDEX:
			_kind_cycle.append(kind)


func _spawn_worker(index: int, workload: String) -> bool:
	"""Spawn one resident with its priorities, schedule and JobAgent row, then band it."""
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
	_worker_skill[index] = _kind_for(index, workload)
	return _band_worker(index, worker_slot, workload)


func _kind_for(index: int, workload: String) -> int:
	"""The job kind -- and therefore, per decision 0022, the skill index -- for this worker."""
	if workload == "uniform":
		return JobsScript.JOB_KIND_KEEP
	return _kind_cycle[(index * KIND_STRIDE) % _kind_cycle.size()]


func _skill_level_for(index: int, workload: String) -> int:
	"""The skill level this worker holds in its own job kind."""
	if workload == "uniform":
		return 0
	return (index * SKILL_LEVEL_STRIDE) % (ResidentsScript.SKILL_LEVEL_MAX + 1)


func _band_worker(index: int, worker_slot: int, workload: String) -> bool:
	"""Place this worker in its mood band, health band and skill level for this workload.

	The `uniform` workload leaves every one of these at its spawn default, so its state -- and
	therefore its digest -- is byte-identical to the fixture committed on 2026-09-07.
	"""
	if workload == "uniform":
		return true
	var mood_band: int = index % MEMORY_TOTAL_BY_MOOD_BAND.size()
	_worker_memory[index] = MEMORY_TOTAL_BY_MOOD_BAND[mood_band]
	var memory: WorkScript.OpResult = _work.set_memory_total(worker_slot,
		_worker_memory[index])
	if not memory.ok:
		return _fail("worker %d memory total refused: %s" % [index, memory.error])
	var health_band: int = (index / MEMORY_TOTAL_BY_MOOD_BAND.size()) % HEALTH_BY_BAND.size()
	var target_health: int = HEALTH_BY_BAND[health_band]
	if target_health != NeedsScript.INITIAL_HEALTH:
		var health: NeedsScript.OpResult = _needs.apply_health_event(worker_slot,
			target_health - NeedsScript.INITIAL_HEALTH)
		if not health.ok:
			return _fail("worker %d health event refused: %s" % [index, health.error])
	var level: int = _skill_level_for(index, workload)
	var xp: int = ResidentsScript.SKILL_XP_PER_LEVEL_SQUARE * level * level
	var written: ResidentsScript.OpResult = _residents.set_skill_xp(worker_slot,
		_worker_skill[index], xp)
	if not written.ok:
		return _fail("worker %d skill XP refused: %s" % [index, written.error])
	return true


func _create_jobs(population: int, workload: String) -> bool:
	"""Create and bind this workload's jobs, filling `_worker_job` and `_progress_slots`."""
	_progress_slots.resize(0)
	if not _is_party:
		for index: int in population:
			if not _create_solo_job(index, workload):
				return false
			_progress_slots.append(_worker_job[index])
		return true
	var index_in_party: int = 0
	var party_index: int = 0
	var coordinator: int = -1
	for index: int in population:
		if index_in_party == 0:
			coordinator = _create_coordinator(index, workload)
			if coordinator < 0:
				return false
			_progress_slots.append(coordinator)
		if not _create_member_job(index, workload, coordinator):
			return false
		index_in_party += 1
		if index_in_party >= PARTY_SIZES[party_index % PARTY_SIZES.size()]:
			index_in_party = 0
			party_index += 1
	return true


func _create_solo_job(index: int, workload: String) -> bool:
	"""Create one single-worker job carrying the whole work total, bind it and put it in WORK."""
	var required: int = _skill_level_for(index, workload)
	var created: JobsScript.OpResult = _jobs.create_job(_worker_skill[index], 0, required,
		LONG_REMAINING_MWU, 0)
	if not created.ok:
		return _fail("worker %d job creation refused: %s" % [index, created.error])
	_worker_job[index] = created.value
	return _bind_and_work(index, created.value)


func _create_coordinator(index: int, workload: String) -> int:
	"""Create one decision 0017 coordinator row holding the shared work total, or refuse.

	Returns the coordinator's job slot. A refusal records `_failure` and returns -1, which the
	caller tests explicitly; nothing downstream may read -1 as a row.
	"""
	var created: JobsScript.OpResult = _jobs.create_job(_worker_skill[index], 0,
		_skill_level_for(index, workload), LONG_REMAINING_MWU, 0)
	if not created.ok:
		_fail("party at worker %d: coordinator creation refused: %s" % [index, created.error])
		return -1
	var promoted: JobsScript.OpResult = _jobs.make_coordinator(created.value)
	if not promoted.ok:
		_fail("party at worker %d: promotion refused: %s" % [index, promoted.error])
		return -1
	var state: JobsScript.OpResult = _jobs.set_state(created.value, JobsScript.JOB_STATE_WORK)
	if not state.ok:
		_fail("party at worker %d: coordinator state refused: %s" % [index, state.error])
		return -1
	return created.value


func _create_member_job(index: int, workload: String, coordinator: int) -> bool:
	"""Create one member job holding no shared progress, bind its worker and attach the party."""
	var created: JobsScript.OpResult = _jobs.create_job(_worker_skill[index], 0,
		_skill_level_for(index, workload), 0, 0)
	if not created.ok:
		return _fail("worker %d member creation refused: %s" % [index, created.error])
	_worker_job[index] = created.value
	var linked: JobsScript.OpResult = _jobs.set_coordinator(created.value, coordinator)
	if not linked.ok:
		return _fail("worker %d party link refused: %s" % [index, linked.error])
	return _bind_and_work(index, created.value)


func _bind_and_work(index: int, job_slot: int) -> bool:
	"""Assign this worker to the job and move the row into JOB_STATE_WORK."""
	var bind_result: JobsScript.OpResult = _jobs.assign_worker(_worker_slots[index], job_slot)
	if not bind_result.ok:
		return _fail("worker %d job binding refused: %s" % [index, bind_result.error])
	var state_result: JobsScript.OpResult = _jobs.set_state(job_slot, JobsScript.JOB_STATE_WORK)
	if not state_result.ok:
		return _fail("worker %d job state refused: %s" % [index, state_result.error])
	return true


func _validate_setup(population: int) -> bool:
	"""Refuse to measure anything unless every row the fixture claims to have built is there."""
	if _residents.population() != population or _residents.living_count() != population:
		return _fail("resident counts are not %d" % population)
	var expected_jobs: int = population + (_progress_slots.size() if _is_party else 0)
	if _jobs.job_count() != expected_jobs or _jobs.agent_count() != population:
		return _fail("job/agent counts are not %d/%d" % [expected_jobs, population])
	for index: int in population:
		if not _validate_setup_row(index):
			return false
	for index: int in _progress_slots.size():
		var remaining: IntMath.IntResult = _jobs.remaining_mwu_of(_progress_slots[index])
		if not remaining.ok or remaining.value != LONG_REMAINING_MWU:
			return _fail("progress row %d has unexpected remaining work" % index)
		var state: IntMath.IntResult = _jobs.state_of(_progress_slots[index])
		if not state.ok or state.value != JobsScript.JOB_STATE_WORK:
			return _fail("progress row %d is not in WORK" % index)
	return true


func _validate_setup_row(index: int) -> bool:
	"""Check one worker's resident, agent and job rows before any tick is timed."""
	var worker: int = _worker_slots[index]
	var job: int = _worker_job[index]
	if not _residents.is_present(worker) or not _residents.is_alive(worker):
		return _fail("worker %d is not present and alive" % index)
	if not _jobs.is_agent_present(worker) or not _jobs.is_job_present(job):
		return _fail("worker %d job/agent row is missing" % index)
	var state: IntMath.IntResult = _jobs.state_of(job)
	if not state.ok or state.value != JobsScript.JOB_STATE_WORK:
		return _fail("worker %d job is not in WORK" % index)
	if not _jobs.resident_may_work(worker).ok:
		return _fail("worker %d may not work" % index)
	var expected_remaining: int = 0 if _is_party else LONG_REMAINING_MWU
	var remaining: IntMath.IntResult = _jobs.remaining_mwu_of(job)
	if not remaining.ok or remaining.value != expected_remaining:
		return _fail("worker %d job has unexpected remaining work" % index)
	var worker_need: IntMath.IntResult = _needs.need_of(worker, 0)
	if not worker_need.ok or worker_need.value != NeedsScript.INITIAL_NEED_VALUE:
		return _fail("worker %d does not have default needs" % index)
	return true


func _record_factors(population: int) -> bool:
	"""Record the §5.2 work factor every worker starts at, so the fixture's spread is reported.

	The factor is read through `work.work_factor_of()` -- the published reader over `needs.gd`'s
	one implementation -- so nothing here re-derives a band, a weight or a clamp.
	"""
	_factor_sum = 0
	_factor_min = NeedsScript.WORK_FACTOR_MAX
	_factor_max = NeedsScript.WORK_FACTOR_MIN
	for index: int in population:
		var factor: IntMath.IntResult = _work.work_factor_of(_worker_slots[index],
			_worker_skill[index])
		if not factor.ok:
			return _fail("worker %d work factor refused: %s" % [index, factor.error])
		_factor_sum += factor.value
		_factor_min = mini(_factor_min, factor.value)
		_factor_max = maxi(_factor_max, factor.value)
	return true


# --- sampling ------------------------------------------------------------------------------------

func _sample(config: String, warmup: int, samples: int, durations_us: PackedInt64Array) -> bool:
	"""Run and discard the warm-up ticks, then time each sampled tick into `durations_us`."""
	for tick: int in warmup:
		if not _tick_config(config):
			_failure = "warmup tick %d: %s" % [tick, _failure]
			return false
	for sample: int in samples:
		var started: int = Time.get_ticks_usec()
		if not _tick_config(config):
			_failure = "sample tick %d: %s" % [sample, _failure]
			return false
		durations_us[sample] = Time.get_ticks_usec() - started
	return true


func _tick_config(config: String) -> bool:
	"""Run exactly one sampled unit of work for this config."""
	match config:
		"needs":
			return _tick_needs()
		"wu":
			return _tick_work()
		"combined":
			return _tick_needs() and _tick_work()
		"loop":
			return _probe_loop()
		"pid":
			return _probe_persistent_id()
		"xp":
			return _probe_xp_write()
		"result":
			return _probe_tick_result()
		"factor":
			return _probe_factor_chain()
		"gate":
			return _probe_work_gate()
		"party_fast":
			return _tick_reset_party(LONG_REMAINING_MWU)
		"party_finish":
			return _tick_reset_party(PARTY_FINISH_MWU)
	return _fail("unknown config %s" % config)


func _tick_needs() -> bool:
	"""One `needs.tick_all()` sweep, refusing unless every living row integrated."""
	var needs_result: NeedsScript.OpResult = _needs.tick_all()
	if not needs_result.ok:
		return _fail("needs tick refused: %s" % needs_result.error)
	if needs_result.value != _worker_slots.size():
		return _fail("needs tick integrated %d rows, expected %d"
			% [needs_result.value, _worker_slots.size()])
	return true


func _tick_work() -> bool:
	"""One productive work tick against every progress row, solo or party as the workload has it."""
	for index: int in _progress_slots.size():
		var progress: int = _progress_slots[index]
		var ticked: bool = _work.tick_party_into(progress, _tick_result) if _is_party \
			else _work.tick_solo_into(progress, _tick_result)
		if not ticked:
			return _fail("work tick %d refused: %s" % [index, _tick_result.error])
		if _tick_result.completed or _tick_result.accepted_mwu <= 0 \
				or _tick_result.remaining_mwu <= 0:
			return _fail("work tick %d violated productive non-completion outcome" % index)
	return true


func _tick_reset_party(remaining_mwu: int) -> bool:
	"""Reset every coordinator's outstanding work, then tick it, timing both.

	The two setter calls are inside the timed region ON PURPOSE and are IDENTICAL in
	`party_fast` and `party_finish`, so the difference between those two configs is the
	acceptance path taken and not the reset. `party_fast` keeps acceptance equal to the party's
	summed potential; `party_finish` forces acceptance below it, which is the only condition
	under which decision 0017's proportional split, largest-fractional-remainder pass and
	persistent-ID tie-break can run at all.
	"""
	var finishing: bool = remaining_mwu == PARTY_FINISH_MWU
	for index: int in _progress_slots.size():
		var coordinator: int = _progress_slots[index]
		if not _jobs.set_remaining_mwu(coordinator, remaining_mwu).ok:
			return _fail("party %d reset refused" % index)
		if not _jobs.set_state(coordinator, JobsScript.JOB_STATE_WORK).ok:
			return _fail("party %d state reset refused" % index)
		if not _work.tick_party_into(coordinator, _tick_result):
			return _fail("party tick %d refused: %s" % [index, _tick_result.error])
		if not _party_outcome_holds(_tick_result, finishing):
			return _fail("party tick %d violated its expected outcome" % index)
	return true


func _party_outcome_holds(tick_result: WorkScript.TickResult, finishing: bool) -> bool:
	"""True when this party tick produced the outcome its config exists to exercise."""
	if finishing:
		return tick_result.completed and tick_result.accepted_mwu == PARTY_FINISH_MWU \
			and tick_result.remaining_mwu == 0
	return not tick_result.completed and tick_result.accepted_mwu > 0 \
		and tick_result.remaining_mwu > 0


# --- isolation probes ----------------------------------------------------------------------------

func _probe_loop() -> bool:
	"""The floor every other probe pays: one pass over the contributor columns and nothing else.

	Subtracting this from another probe is what makes that probe's number about the part it
	names rather than about GDScript's loop and index cost.
	"""
	var accumulator: int = 0
	for index: int in _worker_slots.size():
		var job: int = _worker_job[index]
		var resident: int = _worker_slots[index]
		accumulator += job + resident
	_probe_accumulator = accumulator
	return true


func _probe_persistent_id() -> bool:
	"""The floor plus `jobs.agent_persistent_id_of()`, once per contributor.

	This is the call `work._append_contributor()` makes for decision 0017's tie-break, with the
	same argument, and it is the allocating convenience reader named in the handoff.
	"""
	var accumulator: int = 0
	for index: int in _worker_slots.size():
		var job: int = _worker_job[index]
		var resident: int = _worker_slots[index]
		var identity: IntMath.IntResult = _jobs.agent_persistent_id_of(resident)
		if not identity.ok:
			return _fail("persistent-ID probe refused at %d: %s" % [index, identity.error])
		accumulator += job + resident + identity.value
	_probe_accumulator = accumulator
	return true


func _probe_xp_write() -> bool:
	"""The floor plus the branch `work._credit_xp()` takes when a whole WU actually completes.

	THE VALUE WRITTEN IS THE VALUE READ, not the sum: 3000 sampled writes of +10 XP would raise
	the resident's level and change how many iterations `set_skill_xp()`'s level derivation
	runs, which would measure the probe's own drift rather than the write. The checked add is
	still performed, and an integer add costs the same whichever operand is stored.

	THIS RUNS AT 100% DUTY. `_credit_xp()` reaches this branch only on the tick a resident's
	milli-WU accumulator crosses 1000; `xp_write_duty_ppm_mean` in the result reports how often
	that is for this fixture, and the probe must be scaled by it before it is compared with `wu`.
	"""
	var accumulator: int = 0
	for index: int in _worker_slots.size():
		var job: int = _worker_job[index]
		var resident: int = _worker_slots[index]
		if not _residents.skill_xp_into(resident, _worker_skill[index], _probe_math):
			return _fail("XP probe read refused at %d: %s" % [index, _probe_math.error])
		var current: int = _probe_math.value
		if not IntMath.checked_add_into(current, WorkScript.XP_PER_WU, _probe_math):
			return _fail("XP probe add refused at %d" % index)
		if not _residents.set_skill_xp(resident, _worker_skill[index], current).ok:
			return _fail("XP probe write refused at %d" % index)
		accumulator += job + resident + current
	_probe_accumulator = accumulator
	return true


func _probe_tick_result() -> bool:
	"""The floor plus one escaping `TickResult`, built and read exactly as `work._finish()` does.

	The object is constructed in its refused shape, has its three outcome fields written, is
	read by this caller, and is then dropped.

	ITS BODY IS UNCHANGED BY DECISION 0024 SECTION 2, deliberately, so this probe stays
	comparable with every earlier run. What it no longer describes is the `wu` config beside it:
	since that config ticks into one caller-owned result, this probe now measures the allocation
	the `_into` form REMOVED rather than one it still performs. It remains an isolated ceiling
	and, for the party workload, a large over-estimate -- it builds one result per contributor
	where a party tick builds one per progress row.
	"""
	var accumulator: int = 0
	for index: int in _worker_slots.size():
		var job: int = _worker_job[index]
		var resident: int = _worker_slots[index]
		var out: WorkScript.TickResult = WorkScript.TickResult.new(true, WorkScript.REFUSE_NONE)
		out.accepted_mwu = job
		out.remaining_mwu = LONG_REMAINING_MWU
		out.contributor_count = 1
		if not out.ok or out.completed:
			return _fail("TickResult probe built a wrong shape at %d" % index)
		accumulator += out.accepted_mwu + resident + out.contributor_count
	_probe_accumulator = accumulator
	return true


func _probe_factor_chain() -> bool:
	"""The floor plus the four reader calls `work._compute_factor()` makes, in the same order.

	Skill level, health, mood and then `needs.work_factor()`, every one of them through the
	caller-owned `_into` form the tick uses and into one reused result, so this probe adds no
	allocation of its own. The memory total is read from this fixture's own column, which holds
	the same integer `work.gd` passes from its own.
	"""
	var accumulator: int = 0
	for index: int in _worker_slots.size():
		var job: int = _worker_job[index]
		var resident: int = _worker_slots[index]
		if not _residents.skill_level_into(resident, _worker_skill[index], _probe_math):
			return _fail("factor probe level refused at %d: %s" % [index, _probe_math.error])
		var level: int = _probe_math.value
		if not _needs.health_into(resident, _probe_math):
			return _fail("factor probe health refused at %d: %s" % [index, _probe_math.error])
		var health: int = _probe_math.value
		if not _needs.mood_into(resident, _worker_memory[index], _probe_math):
			return _fail("factor probe mood refused at %d: %s" % [index, _probe_math.error])
		var mood: int = _probe_math.value
		if not _needs.work_factor_into(level, mood, health, _probe_math):
			return _fail("factor probe factor refused at %d: %s" % [index, _probe_math.error])
		accumulator += job + resident + _probe_math.value
	_probe_accumulator = accumulator
	return true


func _probe_work_gate() -> bool:
	"""The floor plus `jobs.resident_may_work_into()`, the §5.3 step-1 gate the tick re-reads.

	This is the one implementation of that gate, called rather than copied, exactly as
	`work._offer_contributor()` calls it and with the same caller-owned result.
	"""
	var accumulator: int = 0
	for index: int in _worker_slots.size():
		var job: int = _worker_job[index]
		var resident: int = _worker_slots[index]
		if not _jobs.resident_may_work_into(resident, _probe_math):
			return _fail("gate probe refused at %d: %s" % [index, _probe_math.error])
		accumulator += job + resident + _probe_math.value
	_probe_accumulator = accumulator
	return true


# --- post-run validation and hashing --------------------------------------------------------------

func _validate_after(config: String) -> bool:
	"""Check the rows the sampled ticks touched are in the state that config must leave them in."""
	for index: int in _worker_slots.size():
		var worker: int = _worker_slots[index]
		var health: IntMath.IntResult = _needs.health_of(worker)
		if not health.ok or health.value <= 0:
			return _fail("worker %d health became invalid" % index)
	var finishing: bool = config == "party_finish"
	for index: int in _progress_slots.size():
		var remaining: IntMath.IntResult = _jobs.remaining_mwu_of(_progress_slots[index])
		var state: IntMath.IntResult = _jobs.state_of(_progress_slots[index])
		if not remaining.ok or not state.ok:
			return _fail("progress row %d became unreadable" % index)
		if finishing and (remaining.value != 0 or state.value != JobsScript.JOB_STATE_COMPLETE):
			return _fail("progress row %d did not finish as party_finish requires" % index)
		if not finishing and remaining.value <= 0:
			return _fail("progress row %d completed unexpectedly" % index)
	return true


func _state_hash() -> String:
	"""SHA-256 of this fixture's canonical state lines; sets `_hash_lines` to the line count."""
	var lines: PackedStringArray = PackedStringArray()
	lines.append("protocol|%s\n" % HASH_PROTOCOL)
	for index: int in _worker_slots.size():
		if not _append_worker_lines(lines, index):
			return ""
	if _is_party and not _append_coordinator_lines(lines):
		return ""
	_hash_lines = lines.size()
	var hashing: HashingContext = HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update("".join(lines).to_utf8_buffer())
	return hashing.finish().hex_encode()


func _append_worker_lines(lines: PackedStringArray, index: int) -> bool:
	"""Append one worker's health, needs, carries, XP and bound-job lines, in v1's order."""
	var worker: int = _worker_slots[index]
	var health: IntMath.IntResult = _needs.health_of(worker)
	var health_remainder: IntMath.IntResult = _needs.health_remainder_of(worker)
	if not health.ok or not health_remainder.ok:
		return _fail("hash health reader refused for worker %d" % index)
	lines.append("health|%d|value|%d\n" % [index, health.value])
	lines.append("health|%d|remainder|%d\n" % [index, health_remainder.value])
	for need: int in NeedsScript.NEED_COUNT:
		var value: IntMath.IntResult = _needs.need_of(worker, need)
		var remainder: IntMath.IntResult = _needs.need_remainder_of(worker, need)
		if not value.ok or not remainder.ok:
			return _fail("hash need reader refused for worker %d need %d" % [index, need])
		lines.append("need|%d|%d|%d\n" % [index, need, value.value])
		lines.append("need_remainder|%d|%d|%d\n" % [index, need, remainder.value])
	var carry: IntMath.IntResult = _work.potential_remainder_of(worker)
	if not carry.ok:
		return _fail("hash work carry reader refused for worker %d" % index)
	lines.append("work_remainder|%d|value|%d\n" % [index, carry.value])
	if not _append_skill_lines(lines, index, worker):
		return false
	return _append_job_lines(lines, "job", index, _worker_job[index])


func _append_skill_lines(lines: PackedStringArray, index: int, worker: int) -> bool:
	"""Append this worker's twelve skill XP values and their retained XP fractions."""
	for skill: int in ResidentsScript.SKILL_COUNT:
		var xp: IntMath.IntResult = _residents.skill_xp_of(worker, skill)
		if not xp.ok:
			return _fail("hash skill XP reader refused for worker %d skill %d" % [index, skill])
		lines.append("skill_xp|%d|%d|%d\n" % [index, skill, xp.value])
		var xp_remainder: IntMath.IntResult = _work.xp_remainder_of(worker, skill)
		if xp_remainder.ok:
			lines.append("xp_remainder|%d|%d|%d\n" % [index, skill, xp_remainder.value])
		elif skill == WorkScript.SKILL_RESERVED_INDEX \
				and xp_remainder.error == String(WorkScript.REFUSE_RESERVED_SKILL):
			lines.append("xp_remainder|%d|%d|reserved\n" % [index, skill])
		else:
			return _fail("unexpected XP remainder refusal")
	return true


func _append_coordinator_lines(lines: PackedStringArray) -> bool:
	"""Append the coordinator rows, which hold this workload's shared progress."""
	for index: int in _progress_slots.size():
		if not _append_job_lines(lines, "coordinator", index, _progress_slots[index]):
			return false
	return true


func _append_job_lines(lines: PackedStringArray, field: String, index: int, job: int) -> bool:
	"""Append one job row's state and outstanding work under `field`."""
	var state: IntMath.IntResult = _jobs.state_of(job)
	var remaining: IntMath.IntResult = _jobs.remaining_mwu_of(job)
	if not state.ok or not remaining.ok:
		return _fail("hash job reader refused for %s %d" % [field, index])
	lines.append("%s|%d|state|%d\n" % [field, index, state.value])
	lines.append("%s|%d|remaining_mwu|%d\n" % [field, index, remaining.value])
	return true


# --- result assembly ------------------------------------------------------------------------------

func _summary(config: String, workload: String, population: int, warmup: int, samples: int,
		durations_us: PackedInt64Array, setup_hash: String, final_hash: String) -> Dictionary:
	"""Assemble the result record for one run: percentiles, digests and fixture facts."""
	var pair_durations_us: PackedInt64Array = PackedInt64Array()
	for pair: int in samples / 2:
		pair_durations_us.append(durations_us[pair * 2] + durations_us[pair * 2 + 1])
	return {
		"schema": "redwall-work-benchmark-v1",
		"hash_protocol": HASH_PROTOCOL,
		"config": config,
		"workload": workload,
		"population": population,
		"warmup_ticks": warmup,
		"sample_ticks": samples,
		"pair_windows": pair_durations_us.size(),
		"setup_hash_sha256": setup_hash,
		"final_hash_sha256": final_hash,
		"hash_lines": _hash_lines,
		"p50_us": _nearest_rank(durations_us, 50),
		"p95_pair_us": _nearest_rank(pair_durations_us, 95),
		"p99_us": _nearest_rank(durations_us, 99),
		"total_sample_us": _sum(durations_us),
		"fixture": _fixture_facts(population),
		"engine_version": Engine.get_version_info(),
	}


func _fixture_facts(population: int) -> Dictionary:
	"""Describe the fixture measured: its shape, its factor spread and its benchmark artifacts.

	`xp_write_duty_ppm_mean` is the mean share of ticks on which a contributor's milli-WU
	accumulator crosses one whole WU and `work._credit_xp()` therefore performs a skill-XP
	write. A tick releases `80*F/1000` milli-WU toward a 1000 milli-WU threshold, so that share
	is `80*F/1000000`, which is exactly `80*F` in parts per million.
	"""
	var mean_factor: int = _factor_sum / population
	return {
		"contributor_count": _worker_slots.size(),
		"progress_row_count": _progress_slots.size(),
		"party_workload": _is_party,
		"work_factor_min": _factor_min,
		"work_factor_max": _factor_max,
		"work_factor_mean": mean_factor,
		"work_factor_sum": _factor_sum,
		"xp_write_duty_ppm_mean": WorkScript.BASE_MWU_PER_TICK * _factor_sum / population,
		"benchmark_artifacts": _benchmark_artifacts(),
	}


func _benchmark_artifacts() -> Dictionary:
	"""Every fixture input that is a choice of this harness rather than a specified value."""
	return {
		"note": "harness inputs, not GDD, decision 0017 or decision 0022 values",
		"long_remaining_mwu": LONG_REMAINING_MWU,
		"party_finish_mwu": PARTY_FINISH_MWU,
		"memory_total_by_mood_band": MEMORY_TOTAL_BY_MOOD_BAND,
		"health_by_band": HEALTH_BY_BAND,
		"party_sizes": PARTY_SIZES,
		"kind_stride": KIND_STRIDE,
		"skill_level_stride": SKILL_LEVEL_STRIDE,
		"resolved_work_hour": HOUR_WORK,
	}


func _nearest_rank(values: PackedInt64Array, percentile: int) -> int:
	"""The nearest-rank percentile of `values`: the ceil(p*n/100)-th smallest sample."""
	var ordered: Array[int] = []
	for value: int in values:
		ordered.append(value)
	ordered.sort()
	var rank: int = (percentile * ordered.size() + 99) / 100
	return ordered[rank - 1]


func _sum(values: PackedInt64Array) -> int:
	"""The total of every sampled duration."""
	var total: int = 0
	for value: int in values:
		total += value
	return total


func _fail(message: String) -> bool:
	"""Record an explicit refusal reason and return false; no caller may read this as progress."""
	_failure = message
	return false


func _write_result(path: String, result: Dictionary) -> int:
	"""Write the result JSON and echo it, returning the process exit code."""
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		printerr("cannot open benchmark output: %s" % path)
		return 1
	file.store_string(JSON.stringify(result) + "\n")
	file.close()
	print("BENCHMARK_RESULT %s" % JSON.stringify(result))
	return 0


func _write_failure(path: String, message: String) -> int:
	"""Write an explicit refusal record and return a nonzero exit code."""
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
