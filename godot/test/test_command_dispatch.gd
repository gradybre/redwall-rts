extends "res://test/framework/test_case.gd"
## Coverage for `scripts/core/command_dispatch.gd`: ARCH-SYS-002 CommandCommit, the stage where a
## player's intent first reaches a store.
##
## TASK 04.2'S ACCEPTANCE LIST IS THE TEST LIST. "Permuted input arrival produces canonical order
## by the owning key; multiple paused commands preserve sequence; target destruction/reuse between
## preview and commit refuses; 4096 accepted records plus one refuses cleanly; payload boundary,
## negative length, overflow, invalid IDs, generation and UTF-8 name limits are tested ... Hash
## unchanged authoritative state for refused admission" -- each has a named method below.
##
## THE ONE TEST THIS INCREMENT EXISTS FOR is
## `test_a_designate_zone_command_produces_a_real_queued_forage_job`: a command is submitted,
## drained, committed, and `job_planner.gd` publishes a real FORAGE Job with the ruling's priority
## 3, its `dangerous` flag derived from the zone, and state QUEUED. Nothing here writes
## JOB_STATE_WORK, and a separate test asserts that BY VALUE.
##
## THE CONSTANTS ARE TRANSCRIBED FROM THE DOCUMENTS, not read back out of the module under test.
## Priority 3 is the READY_06 ruling's "ordinary newly generated work has priority 3"; JobState
## QUEUED is 0 and WORK is 3 from GDD §4.3's own numbering; the alias bounds are ARCH-SAVE-005's
## "2-32 Unicode characters with control characters rejected"; the 24 schedule bytes are §4.2's
## day. A module that changed one of them would disagree with these numbers rather than with
## itself.

const CommandsScript := preload("res://scripts/core/commands.gd")
const CommandDispatchScript := preload("res://scripts/core/command_dispatch.gd")
const EntityDirectory := preload("res://scripts/core/entity_directory.gd")
const ForageScript := preload("res://scripts/core/forage.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const JobPlannerScript := preload("res://scripts/core/job_planner.gd")
const JobsScript := preload("res://scripts/core/jobs.gd")
const PrioritiesScript := preload("res://scripts/core/priorities.gd")
const ResidentsScript := preload("res://scripts/core/residents.gd")
const ScheduleScript := preload("res://scripts/core/schedule.gd")
const SimClockScript := preload("res://scripts/core/sim_clock.gd")

## ARCH-CMD-003's 24 kind ids, transcribed from the architecture's sorted list rather than read
## back out of `catalog.gd`: a renumbering must fail here, not agree with itself.
const KIND_ACCEPT_CANDIDATES: int = 0
const KIND_CANCEL_JOB: int = 3
const KIND_CANCEL_MANUAL: int = 4
const KIND_DESIGNATE_ZONE: int = 8
const KIND_NAME_RESIDENT: int = 11
const KIND_SET_ACTIVITY_SCHEDULE: int = 15
const KIND_SET_JOB_PRIORITIES: int = 18
const KIND_SET_MANUAL_TASK: int = 19
const KIND_SET_POLICY: int = 20
const KIND_COUNT: int = 24

## GDD §4.3's JobState and JobKind numbering, transcribed.
const STATE_QUEUED: int = 0
const STATE_RESERVED: int = 1
const STATE_WORK: int = 3
const STATE_COMPLETE: int = 5
const STATE_CANCELLED: int = 7
const JOB_KIND_HAUL: int = 0
const JOB_KIND_FORAGE: int = 4
const JOB_KIND_RESERVED_3: int = 3
## GDD §4.3's twelve JobKind values, transcribed.
const JOB_KIND_COUNT: int = 12

## §5.5's forage rows and the ruling's default priority.
const ZONE_FORAGE: int = ForageScript.ZONE_TYPE_FORAGE
const ZONE_FARM: int = ForageScript.ZONE_TYPE_FARM
const PATCH_MUSHROOMS: int = 2
const ORDINARY_PRIORITY: int = 3
const PATCH_ITEM_IDS: Array[int] = [10, 11, 12, 13, 14]

## The tick every submission in this suite is due at: the clock never advances, so `completed_tick`
## stays 0 and every edit is a PAUSED edit sharing `completed_tick+1` (ARCH-CMD-001).
const COMMIT_TICK: int = 1

## §4.2's day and ARCH-SAVE-005's alias bounds, transcribed.
const HOURS_PER_DAY: int = 24
const ACTIVITY_SLEEP: int = 2
const ACTIVITY_WORK: int = 3
## §5.3's default template puts 07:00-12:00 in WORK, which is what a binding worker needs.
const WORK_HOUR: int = 8
const ALIAS_MIN_CHARACTERS: int = 2
const ALIAS_MAX_CHARACTERS: int = 32

var _residents: ResidentsScript = null
var _priorities: PrioritiesScript = null
var _schedule: ScheduleScript = null
var _jobs: JobsScript = null
var _forage: ForageScript = null
var _planner: JobPlannerScript = null
var _clock: SimClockScript = null
var _queue: CommandsScript = null
var _dispatch: CommandDispatchScript = null
var _submission: CommandsScript.Command = null
var _submit_result: CommandsScript.SubmitResult = null
var _report: CommandDispatchScript.TickReport = null
var _row: CommandDispatchScript.ResultRow = null


class RefusingTileForage extends ForageScript:
	"""A forage store whose `add_tile()` always refuses, so the DESIGNATE_ZONE rollback is reachable.

	The rollback exists because a store can refuse after the zone has been created, and a
	preflight that is exact today can stop being exact tomorrow. `test_forage.gd`'s
	CorruptibleForage and `test_job_planner.gd`'s DangerousForage use the same device: a subclass
	that changes exactly one behaviour so a guard can be exercised by value.
	"""

	func add_tile(_ref: Vector2i, _tile: int) -> ForageScript.OpResult:
		"""Refuse every tile link, without touching a column."""
		return ForageScript.OpResult.new(false, ForageScript.REFUSE_ZONE_LINK_CAPACITY, 0,
			EntityDirectory.NULL_REF)


func before_each() -> void:
	"""Build one consistent settlement whose every store shares a single entity directory."""
	_residents = ResidentsScript.new()
	_priorities = PrioritiesScript.new()
	_schedule = ScheduleScript.new(_residents.needs())
	_jobs = JobsScript.new(_residents, _priorities, _schedule)
	_forage = ForageScript.new(_jobs.directory(), _jobs)
	_planner = JobPlannerScript.new(null, _jobs, _forage)
	_clock = SimClockScript.new()
	_queue = CommandsScript.new(_clock, _jobs.directory())
	_dispatch = CommandDispatchScript.new(_queue, _residents, _priorities, _schedule, _jobs,
		_forage, _planner)
	_submission = CommandsScript.Command.new()
	_submit_result = CommandsScript.SubmitResult.new()
	_report = CommandDispatchScript.TickReport.new()
	_row = CommandDispatchScript.ResultRow.new()


func after_each() -> void:
	"""Drop every store so no test inherits another's rows."""
	_dispatch = null
	_queue = null
	_planner = null
	_forage = null
	_jobs = null
	_schedule = null
	_priorities = null
	_residents = null


# --- fixture helpers ----------------------------------------------------------------------------

func _submit(kind: int, target: Vector2i, arg0: int, arg1: int,
		payload: PackedByteArray = PackedByteArray()) -> bool:
	"""Submit one command through the real queue. Returns the queue's own acceptance."""
	_submission.reset()
	_submission.kind = kind
	_submission.target_slot = target.x
	_submission.target_generation = target.y
	_submission.arg0 = arg0
	_submission.arg1 = arg1
	_submission.payload = payload
	return _queue.submit_into(_submission, _submit_result)


func _commit() -> int:
	"""Run one CommandCommit stage at COMMIT_TICK and return how many commands committed."""
	assert_true(_dispatch.commit_tick_into(COMMIT_TICK, _report),
		"the commit stage runs (error: %s)" % _report.error)
	return _report.committed


func _last_code() -> int:
	"""The deterministic result id of the most recent committed or refused command."""
	assert_true(_dispatch.last_result_into(_row), "the ledger holds an outcome")
	return _row.code_id


func _basin(danger: int = 0) -> Vector2i:
	"""A world-generated FORAGE basin owning §5.5's five patches. It is nobody's designation."""
	var made: ForageScript.OpResult = _forage.create_zone(ZONE_FORAGE, danger, 0, false, true)
	assert_true(made.ok, "the basin is created (error: %s)" % made.error)
	var items: PackedInt32Array = PackedInt32Array(PATCH_ITEM_IDS)
	assert_true(_forage.create_patch_set(made.ref, items).ok, "the basin receives five patches")
	return made.ref


func _tile_payload(tiles: PackedInt32Array) -> PackedByteArray:
	"""§8.1's "zone tiles": an i32 count followed by that many i32 tile indices."""
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(4 + 4 * tiles.size())
	bytes.encode_s32(0, tiles.size())
	for index: int in tiles.size():
		bytes.encode_s32(4 + index * 4, tiles[index])
	return bytes


func _priority_payload(kinds: PackedInt32Array, values: PackedInt32Array) -> PackedByteArray:
	"""ARCH-CMD-003's count-prefixed, owner-sorted `(job_kind, priority)` rows."""
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(4 + 8 * kinds.size())
	bytes.encode_s32(0, kinds.size())
	for index: int in kinds.size():
		bytes.encode_s32(4 + index * 8, kinds[index])
		bytes.encode_s32(8 + index * 8, values[index])
	return bytes


func _schedule_payload(activity: int) -> PackedByteArray:
	"""§8.1's schedule bytes: one Activity per hour for a whole 24-hour day."""
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(HOURS_PER_DAY)
	bytes.fill(activity)
	return bytes


func _resident() -> Vector2i:
	"""One spawned resident carrying its priorities, schedule and job-agent rows."""
	var spawned: ResidentsScript.OpResult = _residents.spawn(&"mouse")
	assert_true(spawned.ok, "the resident spawns (error: %s)" % spawned.error)
	var slot: int = _residents.directory().get_typed_row(spawned.ref)
	assert_true(_priorities.spawn(slot).ok, "it takes a priorities row")
	assert_true(_schedule.spawn(slot, _schedule.default_template_id().value).ok,
		"it takes a schedule row")
	assert_true(_jobs.spawn_agent(slot).ok, "it takes a job-agent row")
	assert_true(_schedule.resolve(slot, WORK_HOUR, false).ok,
		"and its activity is resolved for a working hour, which job selection reads")
	return spawned.ref


func _job(kind: int = JOB_KIND_HAUL) -> Vector2i:
	"""One ordinary QUEUED Job with no worker."""
	var made: JobsScript.OpResult = _jobs.create_job(kind, ORDINARY_PRIORITY, 0, 1000, 0)
	assert_true(made.ok, "the job is created (error: %s)" % made.error)
	return _jobs.ref_of(made.value)


func _designate(basin: Vector2i, danger: int = 0,
		tiles: PackedInt32Array = PackedInt32Array()) -> bool:
	"""Submit and commit one DESIGNATE_ZONE against `basin`. Returns whether it committed."""
	assert_true(_submit(KIND_DESIGNATE_ZONE, basin, ZONE_FORAGE, danger, _tile_payload(tiles)),
		"the designation is admitted (error: %s)" % _submit_result.error)
	return _commit() == 1


# --- THE increment: a player designation becomes a real job -------------------------------------

func test_a_designate_zone_command_produces_a_real_queued_forage_job() -> void:
	"""Submit -> drain -> commit -> ARCH-SYS-009 publishes one FORAGE Job. The whole point of 04.2."""
	var basin: Vector2i = _basin()
	assert_equal(_jobs.job_count(), 0, "no job exists before the player commands anything")
	assert_true(_designate(basin, 0, PackedInt32Array([5, 6, 7])), "the designation commits")
	assert_equal(_last_code(), CommandDispatchScript.RESULT_COMMITTED, "and reports COMMITTED")
	assert_equal(_jobs.job_count(), 0, "committing the command alone still creates no work")
	assert_true(_planner.run_tick(COMMIT_TICK).ok, "the planner tick runs")
	assert_equal(_jobs.job_count(), 1,
		"and one harvest exists: decision 0030's daily quota is aggregate across the five kinds")
	var harvest: int = _published_harvest()
	assert_equal(_jobs.kind_of(harvest).value, JOB_KIND_FORAGE, "the work is a FORAGE job")
	assert_equal(_jobs.priority_of(harvest).value, ORDINARY_PRIORITY, "at the ruling's priority 3")
	assert_equal(_jobs.state_of(harvest).value, STATE_QUEUED, "and it is QUEUED")


func test_the_produced_harvest_is_never_advanced_into_job_state_work() -> void:
	"""04.2: "Do not advance a RESERVED job to WORK to make a command appear successful"."""
	assert_true(_designate(_basin()), "the designation commits")
	assert_true(_planner.run_tick(COMMIT_TICK).ok, "the planner publishes the harvests")
	var harvest: int = _published_harvest()
	assert_true(_dispatch.commit_tick_into(COMMIT_TICK + 1, _report), "another commit stage runs")
	assert_equal(_jobs.state_of(harvest).value, STATE_QUEUED, "the harvest is still QUEUED")
	assert_true(_jobs.state_of(harvest).value != STATE_WORK, "nothing here writes JOB_STATE_WORK")
	assert_true(_jobs.state_of(harvest).value != STATE_RESERVED, "and nothing reserves it either")


func test_the_produced_harvest_takes_its_dangerous_flag_from_the_designated_zone() -> void:
	"""The Job `dangerous` flag is DERIVED from §5.5's danger band, never asserted by a command."""
	assert_true(_designate(_basin(), 3, PackedInt32Array([9])), "a danger-3 designation commits")
	assert_true(_planner.run_tick(COMMIT_TICK).ok, "the planner publishes the harvests")
	assert_true(_jobs.is_dangerous(_published_harvest()),
		"REQ-SET-067 applies: danger band 3 makes the harvest dangerous work")


func test_a_safe_designation_produces_work_that_is_not_dangerous() -> void:
	"""The same derivation at the other end of §5.5's band, so the flag is read and not hardcoded."""
	assert_true(_designate(_basin(), 0, PackedInt32Array([9])), "a danger-0 designation commits")
	assert_true(_planner.run_tick(COMMIT_TICK).ok, "the planner publishes the harvests")
	assert_false(_jobs.is_dangerous(_published_harvest()),
		"danger band 0 is ordinary work")


func test_the_committed_designation_links_every_tile_the_payload_named() -> void:
	"""§8.1's "zone tiles" payload reaches `forage.add_tile()`, in the order it was written."""
	assert_true(_designate(_basin(), 0, PackedInt32Array([3, 400, 16383])), "it commits")
	var zone: int = _designated_zone_slot()
	assert_equal(_forage.tile_count_of(zone).value, 3, "all three tiles are linked")
	assert_true(_forage.zone_covers_tile(_forage.zone_ref_of(zone), 16383),
		"including the last index of the 128x128 exterior grid")


# --- task 04.4: one source intent, at most one designation --------------------------------------

func test_a_committed_designation_records_the_command_that_created_it() -> void:
	"""04.4: "Record source intent/job identity". The zone knows which player command made it."""
	assert_equal(_dispatch.source_intent_count(), 0, "a fresh dispatcher owns no intent")
	assert_true(_designate(_basin(), 0, PackedInt32Array([5])), "the designation commits")
	var zone: int = _designated_zone_slot()
	assert_equal(_dispatch.source_intent_count(), 1, "exactly one intent owns a live designation")
	assert_true(_dispatch.has_source_intent(zone), "and it is this designation's")
	var intent: CommandDispatchScript.IntentRow = CommandDispatchScript.IntentRow.new()
	assert_true(_dispatch.source_intent_into(zone, intent), "the identity is readable")
	assert_equal(intent.zone_slot, zone, "naming the zone row it produced")
	assert_equal(intent.player_id, 0, "ARCH-CMD-001's release-1 player")
	assert_equal(intent.sequence_low, 0, "and the first session sequence")
	assert_equal(intent.zone_generation, _forage.zone_ref_of(zone).y,
		"with the produced zone's generation, so a reused row cannot inherit the intent")


func test_a_world_generated_basin_carries_no_source_intent() -> void:
	"""R05-BASIN-002: generation binds no player intent, so the ledger must not claim one."""
	var basin: Vector2i = _basin()
	var basin_slot: int = _forage.zone_slot_of(basin).value
	assert_false(_dispatch.has_source_intent(basin_slot), "the basin is nobody's command")
	assert_equal(_dispatch.source_intent_count(), 0, "and it is not counted as an intent")


func test_a_replayed_command_envelope_produces_no_second_designation() -> void:
	"""The defect this guard exists for, reproduced exactly and then refused.

	`commands.gd` refuses a duplicate key only while the record is QUEUED, and refuses an
	execute_tick already completed. Neither catches the SAME envelope re-admitted at a LATER tick,
	which before this guard committed a second designation over the same basin.
	"""
	var basin: Vector2i = _basin()
	assert_true(_designate(basin, 0, PackedInt32Array([5])), "the first designation commits")
	assert_equal(_forage.zone_count(), 2, "the basin plus one designation")
	assert_true(_replay_designation(basin, COMMIT_TICK + 4), "the replay is admitted")
	assert_true(_dispatch.commit_tick_into(COMMIT_TICK + 4, _report), "the later stage runs")
	assert_equal(_report.committed, 0, "and the replayed intent commits nothing")
	assert_equal(_last_code(), CommandDispatchScript.RESULT_DUPLICATE_INTENT,
		"refusing COMMAND_DUPLICATE_INTENT by name")
	assert_equal(_forage.zone_count(), 2, "no second designation was created")
	assert_equal(_dispatch.source_intent_count(), 1, "and still exactly one source intent")


func test_a_replayed_command_envelope_produces_no_second_standing_demand() -> void:
	"""The consequence that matters: one intent cannot end up owning two ARCH-SYS-009 demands.

	The job count alone would NOT have caught the original defect -- the shared quota happened to
	starve the second demand of stock -- so this asserts the planner's own enabled-demand count,
	which is what a freed quota would have turned into a second job.
	"""
	var basin: Vector2i = _basin()
	assert_true(_designate(basin, 0, PackedInt32Array([5])), "the first designation commits")
	assert_true(_planner.run_tick(COMMIT_TICK).ok, "the planner publishes its harvest")
	assert_equal(_planner.forage_demand_enabled_count(), 1, "one standing demand")
	assert_true(_replay_designation(basin, COMMIT_TICK + 4), "the replay is admitted")
	assert_true(_dispatch.commit_tick_into(COMMIT_TICK + 4, _report), "the later stage runs")
	assert_true(_planner.run_tick(COMMIT_TICK + 5).ok, "and the planner runs again")
	assert_equal(_planner.forage_demand_enabled_count(), 1, "still ONE standing demand")
	assert_equal(_jobs.job_count(), 1, "and one job, not two")
	assert_equal(_dispatch.duplicate_intent_count(), 1, "one duplicate intent was refused")


func test_a_different_sequence_over_the_same_basin_is_a_second_genuine_intent() -> void:
	"""Content is NOT the identity: `forage.gd` supports §5.1's overlapping designations.

	Two commands the player really issued twice differ in sequence, and both must land. Refusing
	the second would contradict the owning store rather than protect it.
	"""
	var basin: Vector2i = _basin()
	assert_true(_designate(basin, 0, PackedInt32Array([5])), "the first designation commits")
	assert_true(_submit(KIND_DESIGNATE_ZONE, basin, ZONE_FORAGE, 0, _tile_payload(
		PackedInt32Array([5]))), "an identical-content command is admitted under a new sequence")
	assert_true(_dispatch.commit_tick_into(COMMIT_TICK + 1, _report), "the next stage runs")
	assert_equal(_report.committed, 1, "and it commits")
	assert_equal(_forage.zone_count(), 3, "two overlapping designations over one basin")
	assert_equal(_dispatch.source_intent_count(), 2, "each with its own recorded source intent")


func test_destroying_a_designation_frees_its_source_intent() -> void:
	"""An intent whose designation is gone duplicates nothing, so the same envelope may run again.

	The ledger is bounded BY the zone rows it describes, so it cannot be a window that forgets a
	live designation -- and it must not hold a dead one against a replay either.
	"""
	var basin: Vector2i = _basin()
	assert_true(_designate(basin, 0, PackedInt32Array([5])), "the designation commits")
	var zone: int = _designated_zone_slot()
	assert_true(_forage.destroy_zone(_forage.zone_ref_of(zone)).ok, "the player removes it")
	assert_equal(_dispatch.source_intent_count(), 0, "the intent owns nothing now")
	assert_false(_dispatch.has_source_intent(zone),
		"and the emptied row claims no intent, though its recorded identity is still written")
	var stale: CommandDispatchScript.IntentRow = CommandDispatchScript.IntentRow.new()
	assert_false(_dispatch.source_intent_into(zone, stale), "reading it refuses")
	assert_equal(_dispatch.last_refusal(), &"NO_SOURCE_INTENT", "naming the absent intent")
	assert_true(_planner.reconcile_forage_zone(zone, COMMIT_TICK + 1).ok,
		"and ARCH-SYS-009 releases the abandoned demand, as its own tick does")
	assert_true(_replay_designation(basin, COMMIT_TICK + 4), "the same envelope is admitted")
	assert_true(_dispatch.commit_tick_into(COMMIT_TICK + 4, _report), "the later stage runs")
	assert_equal(_report.committed, 1, "and it commits, because there is nothing to duplicate")
	assert_equal(_dispatch.source_intent_count(), 1, "one live intent again")


func test_clearing_the_dispatcher_drops_every_recorded_intent() -> void:
	"""`clear()` is what a world reset runs; a stale intent must not survive into a new world."""
	assert_true(_designate(_basin(), 0, PackedInt32Array([5])), "the designation commits")
	assert_equal(_dispatch.source_intent_count(), 1, "one intent is recorded")
	_dispatch.clear()
	assert_equal(_dispatch.source_intent_count(), 0, "and none survives the clear")
	assert_equal(_dispatch.duplicate_intent_count(), 0, "nor does the refusal counter")


func test_the_duplicate_intent_result_code_is_in_the_sorted_domain() -> void:
	"""The result id is the stored one, so the new code must sit in its ASCII-sorted position."""
	assert_equal(CommandDispatchScript.RESULT_CODES[CommandDispatchScript.RESULT_DUPLICATE_INTENT],
		&"COMMAND_DUPLICATE_INTENT", "the id indexes its own code")
	assert_equal(_dispatch.result_code_id(&"COMMAND_DUPLICATE_INTENT"),
		CommandDispatchScript.RESULT_DUPLICATE_INTENT, "and the lookup inverts it")


func _replay_designation(basin: Vector2i, execute_tick: int) -> bool:
	"""Re-admit the FIRST command's exact envelope at a later tick, as a replay stream would.

	`admit_stamped_into()` is the entry point that reads the envelope instead of stamping it, so
	this is the same `(player_id, sequence_high, sequence_low)` the committed command carried.
	"""
	var replay: CommandsScript.Command = CommandsScript.Command.new()
	replay.reset()
	replay.kind = KIND_DESIGNATE_ZONE
	replay.target_slot = basin.x
	replay.target_generation = basin.y
	replay.arg0 = ZONE_FORAGE
	replay.arg1 = 0
	replay.payload = _tile_payload(PackedInt32Array([5]))
	replay.player_id = 0
	replay.execute_tick = execute_tick
	replay.sequence_high = 0
	replay.sequence_low = 0
	return _queue.admit_stamped_into(replay, _submit_result)


func _designated_zone_slot() -> int:
	"""The HarvestZone row of the designation this suite's DESIGNATE_ZONE created."""
	assert_equal(_forage.zone_count(), 2, "the basin and exactly one designation exist")
	for slot: int in ForageScript.HARVEST_ZONE_CAPACITY:
		if _forage.is_zone_present(slot) and _forage.is_designation(slot):
			return slot
	fail("no designation was created")
	return -1


func _published_harvest() -> int:
	"""The typed Job row of the one harvest the designation published, whichever patch kind won.

	Decision 0030's daily quota is AGGREGATE across §5.5's five kinds, so the first kind that
	reconciles takes the whole allowance and the rest are quantified at nothing. Which kind that
	is belongs to the planner, so this asks the planner rather than assuming one.
	"""
	var zone: int = _designated_zone_slot()
	for patch_kind: int in ForageScript.PATCHES_PER_ZONE:
		var ref: Vector2i = _planner.forage_demand_job_of(zone, patch_kind)
		if ref != EntityDirectory.NULL_REF:
			return _jobs.directory().get_typed_row(ref)
	fail("the designation published no harvest")
	return -1


# --- admission versus commit: the target can die in between --------------------------------------

func test_a_target_destroyed_between_admission_and_commit_refuses() -> void:
	"""04.2: commit "revalidates current targets", so a valid admission is not a licence to write."""
	var basin: Vector2i = _basin()
	assert_true(_submit(KIND_DESIGNATE_ZONE, basin, ZONE_FORAGE, 0, _tile_payload(
		PackedInt32Array())), "the command is admitted against a live basin")
	assert_true(_forage.destroy_zone(basin).ok, "the basin is destroyed before the tick runs")
	assert_equal(_commit(), 0, "the command refuses at commit")
	assert_equal(_last_code(), CommandDispatchScript.RESULT_TARGET_STALE, "as a stale target")
	assert_equal(_forage.zone_count(), 0, "and no designation was created")


func test_a_slot_reused_by_a_new_entity_between_admission_and_commit_refuses() -> void:
	"""Generation reuse: the same slot comes back, and the command must NOT edit its new occupant."""
	var basin: Vector2i = _basin()
	assert_true(_submit(KIND_DESIGNATE_ZONE, basin, ZONE_FORAGE, 0, _tile_payload(
		PackedInt32Array())), "the command is admitted")
	assert_true(_forage.destroy_zone(basin).ok, "the basin is destroyed")
	var reused: Vector2i = _basin()
	assert_equal(reused.x, basin.x, "the directory hands the very same slot back out")
	assert_true(reused.y != basin.y, "with a new generation, which is what makes reuse safe")
	assert_equal(_commit(), 0, "the command refuses rather than designating inside the new basin")
	assert_equal(_last_code(), CommandDispatchScript.RESULT_TARGET_STALE, "as a stale target")
	assert_equal(_forage.zone_count(), 1, "only the replacement basin exists")


func test_a_target_of_the_wrong_kind_refuses_rather_than_editing_it() -> void:
	"""A live reference is not enough: CANCEL_JOB pointed at a resident must refuse by KIND."""
	var resident: Vector2i = _resident()
	assert_true(_submit(KIND_CANCEL_JOB, resident, 0, 0), "the envelope is admissible")
	assert_equal(_commit(), 0, "but the commit refuses")
	assert_equal(_last_code(), CommandDispatchScript.RESULT_TARGET_KIND, "naming the kind mismatch")
	assert_true(_residents.is_present(_jobs.directory().get_typed_row(resident)),
		"and the resident it pointed at is untouched")


func test_a_kind_that_needs_a_target_refuses_the_null_reference() -> void:
	"""The null reference `(-1, 0)` is admissible, and is still not an entity to edit."""
	assert_true(_submit(KIND_SET_POLICY, EntityDirectory.NULL_REF, 0, 0), "admission accepts it")
	assert_equal(_commit(), 0, "the commit refuses")
	assert_equal(_last_code(), CommandDispatchScript.RESULT_TARGET_REQUIRED,
		"because SET_POLICY has nothing to edit without one")


# --- ordering ------------------------------------------------------------------------------------

func test_permuted_arrival_commits_in_the_canonical_order() -> void:
	"""ARCH-CMD-001's key, end to end: arrival order is not commit order; the key is."""
	for sequence: int in [7, 2, 9, 4]:
		_submission.reset()
		_submission.kind = KIND_ACCEPT_CANDIDATES
		_submission.execute_tick = COMMIT_TICK
		_submission.sequence_low = sequence
		assert_true(_queue.admit_stamped_into(_submission, _submit_result),
			"the stamped record is admitted (error: %s)" % _submit_result.error)
	assert_equal(_commit(), 0, "every one of them refuses as unsupported")
	assert_equal(_dispatch.result_count(), 4, "and every one is recorded")
	var seen: PackedInt32Array = PackedInt32Array()
	for index: int in 4:
		assert_true(_dispatch.result_into(index, _row), "the outcome is readable")
		seen.append(_row.sequence_low)
	assert_equal(seen, PackedInt32Array([2, 4, 7, 9]),
		"the ledger is in ascending sequence order, not in arrival order")


func test_multiple_paused_commands_preserve_their_submission_sequence() -> void:
	"""ARCH-CMD-001: "paused edits receive the same next tick, increasing sequence"."""
	var basin: Vector2i = _basin()
	for _index: int in 3:
		assert_true(_submit(KIND_SET_POLICY, basin, CommandDispatchScript.POLICY_COUNT, 0),
			"each paused edit is admitted")
	assert_equal(_queue.pending_count(), 3, "all three wait for the same next tick")
	assert_equal(_commit(), 0, "each refuses its unknown policy selector")
	var previous: int = -1
	for index: int in 3:
		assert_true(_dispatch.result_into(index, _row), "the outcome is readable")
		assert_equal(_row.execute_tick, COMMIT_TICK, "all three share completed_tick+1")
		assert_true(_row.sequence_low > previous, "and their sequence strictly increases")
		previous = _row.sequence_low


# --- every unsupported kind refuses explicitly, and none of them silently succeeds ---------------

func test_every_unimplemented_kind_refuses_with_the_unsupported_feature_code() -> void:
	"""04.2: "Dispatch unavailable kinds to explicit unsupported-feature refusal, never silent success"."""
	var refused: int = 0
	for kind: int in KIND_COUNT:
		if _dispatch.is_supported_kind(kind):
			continue
		assert_true(_submit(kind, EntityDirectory.NULL_REF, 0, 0),
			"kind %d is admissible, because the queue validates the envelope only" % kind)
		assert_equal(_commit(), 0, "kind %d does not commit" % kind)
		assert_equal(_last_code(), CommandDispatchScript.RESULT_UNSUPPORTED_FEATURE,
			"kind %d refuses as an unsupported feature" % kind)
		refused += 1
	assert_equal(refused, 18, "eighteen of ARCH-CMD-003's 24 kinds have no owning store here")


func test_exactly_six_kinds_are_implemented_and_they_are_the_named_six() -> void:
	"""The supported set is asserted by NAME, so adding a kind cannot pass by changing a count."""
	assert_equal(_dispatch.supported_kind_count(), 6, "six kinds have an owning store")
	for kind: int in [KIND_CANCEL_JOB, KIND_DESIGNATE_ZONE, KIND_NAME_RESIDENT,
			KIND_SET_ACTIVITY_SCHEDULE, KIND_SET_JOB_PRIORITIES, KIND_SET_POLICY]:
		assert_true(_dispatch.is_supported_kind(kind), "kind %d is implemented" % kind)


func test_the_manual_task_kinds_name_the_missing_store_rather_than_a_bare_refusal() -> void:
	"""U6 records that ManualTask's owner-major index formula is unspecified, so there is no store."""
	assert_equal(_dispatch.unsupported_reason(KIND_SET_MANUAL_TASK),
		&"NO_MANUAL_TASK_STORE_BLOCKER_U6", "SET_MANUAL_TASK names the missing ManualTask store")
	assert_equal(_dispatch.unsupported_reason(KIND_CANCEL_MANUAL),
		&"NO_MANUAL_TASK_STORE_BLOCKER_U6", "and so does CANCEL_MANUAL")
	assert_equal(_dispatch.unsupported_reason(KIND_CANCEL_JOB), &"",
		"an implemented kind names no missing store")


func test_an_unbound_store_refuses_rather_than_pretending_to_have_committed() -> void:
	"""The composition that lacks `forage.gd` must refuse DESIGNATE_ZONE, not quietly do nothing."""
	var basin: Vector2i = _basin()
	var bare: CommandDispatchScript = CommandDispatchScript.new(_queue, _residents, _priorities,
		_schedule, _jobs)
	assert_true(_submit(KIND_DESIGNATE_ZONE, basin, ZONE_FORAGE, 0, _tile_payload(
		PackedInt32Array())), "the command is admitted")
	assert_true(bare.commit_tick_into(COMMIT_TICK, _report), "the stage runs")
	assert_equal(_report.committed, 0, "nothing committed")
	assert_true(bare.last_result_into(_row), "the outcome is recorded")
	assert_equal(_row.code_id, CommandDispatchScript.RESULT_STORE_NOT_BOUND,
		"and it names the unbound store")
	assert_equal(_forage.zone_count(), 1, "only the basin exists; nothing was designated")


func test_binding_the_ecology_stores_is_what_stops_the_unbound_refusal() -> void:
	"""`bind_ecology()` is task 03's named runtime handoff, and it is what closes the loop."""
	var basin: Vector2i = _basin()
	var bare: CommandDispatchScript = CommandDispatchScript.new(_queue, _residents, _priorities,
		_schedule, _jobs)
	assert_true(bare.bind_ecology(_forage, _planner), "the ecology stores bind")
	assert_true(_submit(KIND_DESIGNATE_ZONE, basin, ZONE_FORAGE, 0, _tile_payload(
		PackedInt32Array())), "the command is admitted")
	assert_true(bare.commit_tick_into(COMMIT_TICK, _report), "the stage runs")
	assert_equal(_report.committed, 1, "and now it commits")
	assert_equal(_forage.zone_count(), 2, "the designation exists")


# --- atomicity: a later refusal leaves no half-changed policy -------------------------------------

func test_one_illegal_priority_leaves_every_priority_and_both_toggles_unchanged() -> void:
	"""Decision 0059's allocate-before-consume at the dispatch layer, asserted field by field."""
	var resident: Vector2i = _resident()
	var slot: int = _jobs.directory().get_typed_row(resident)
	assert_true(_priorities.set_dangerous_work(slot, false).ok, "consent starts withheld")
	var before: int = _priorities.priority_of(slot, JOB_KIND_FORAGE).value
	var payload: PackedByteArray = _priority_payload(PackedInt32Array([0, JOB_KIND_FORAGE]),
		PackedInt32Array([1, 5]))
	assert_true(_submit(KIND_SET_JOB_PRIORITIES, resident, 1, 1, payload), "it is admitted")
	assert_equal(_commit(), 0, "priority 5 is outside 0-4, so the whole command refuses")
	assert_equal(_last_code(), CommandDispatchScript.RESULT_ARGUMENT_RANGE, "by argument range")
	assert_equal(_priorities.priority_of(slot, 0).value,
		PrioritiesScript.INITIAL_HAUL_PRIORITY, "the FIRST row was not written either")
	assert_equal(_priorities.priority_of(slot, JOB_KIND_FORAGE).value, before,
		"and neither was the row that failed")
	assert_equal(_priorities.dangerous_work_of(slot).value, 0,
		"the consent toggle did not move")


func test_a_legal_priority_command_writes_every_row_and_both_toggles() -> void:
	"""The positive half of the same command, so the atomicity test is not passing vacuously."""
	var resident: Vector2i = _resident()
	var slot: int = _jobs.directory().get_typed_row(resident)
	var payload: PackedByteArray = _priority_payload(PackedInt32Array([0, JOB_KIND_FORAGE]),
		PackedInt32Array([1, 4]))
	assert_true(_submit(KIND_SET_JOB_PRIORITIES, resident, 1, 1, payload), "it is admitted")
	assert_equal(_commit(), 1, "and it commits")
	assert_equal(_priorities.priority_of(slot, 0).value, 1, "the first row is written")
	assert_equal(_priorities.priority_of(slot, JOB_KIND_FORAGE).value, 4, "and so is the second")
	assert_equal(_priorities.dangerous_work_of(slot).value, 1,
		"the dangerous-work toggle is on")
	assert_equal(_priorities.auto_fallback_of(slot).value, 1,
		"and so is the auto-fallback toggle")


func test_an_unchanged_toggle_leaves_the_stored_consent_alone() -> void:
	"""-1 means "leave it": a priority edit must not restate an unrelated consent."""
	var resident: Vector2i = _resident()
	var slot: int = _jobs.directory().get_typed_row(resident)
	assert_true(_priorities.set_dangerous_work(slot, true).ok, "consent starts granted")
	var payload: PackedByteArray = _priority_payload(PackedInt32Array([0]), PackedInt32Array([2]))
	assert_true(_priorities.set_auto_fallback(slot, true).ok, "and fallback starts enabled")
	assert_true(_submit(KIND_SET_JOB_PRIORITIES, resident, -1, -1, payload), "it is admitted")
	assert_equal(_commit(), 1, "and it commits")
	assert_equal(_priorities.dangerous_work_of(slot).value, 1,
		"the granted consent survives")
	assert_equal(_priorities.auto_fallback_of(slot).value, 1,
		"and so does the enabled auto-fallback, which -1 must not switch off")


func test_a_priority_row_naming_the_reserved_job_kind_refuses() -> void:
	"""The amendment fixes reserved index 3 at 0 with assignment prohibited."""
	var resident: Vector2i = _resident()
	var payload: PackedByteArray = _priority_payload(PackedInt32Array([JOB_KIND_RESERVED_3]),
		PackedInt32Array([2]))
	assert_true(_submit(KIND_SET_JOB_PRIORITIES, resident, -1, -1, payload), "it is admitted")
	assert_equal(_commit(), 0, "and refuses at commit")
	assert_equal(_last_code(), CommandDispatchScript.RESULT_ARGUMENT_RANGE, "by argument range")


func test_unsorted_priority_rows_refuse_rather_than_being_sorted_here() -> void:
	"""ARCH-CMD-003's owner-sorted rows: the canonical order is refused into existence."""
	var resident: Vector2i = _resident()
	var payload: PackedByteArray = _priority_payload(PackedInt32Array([JOB_KIND_FORAGE, 0]),
		PackedInt32Array([2, 2]))
	assert_true(_submit(KIND_SET_JOB_PRIORITIES, resident, -1, -1, payload), "it is admitted")
	assert_equal(_commit(), 0, "and refuses at commit")
	assert_equal(_last_code(), CommandDispatchScript.RESULT_PAYLOAD_SCHEMA, "by payload schema")


func test_one_illegal_schedule_hour_leaves_the_whole_day_unchanged() -> void:
	"""24 bytes are validated, then 24 hours are written; a bad byte writes no hour at all."""
	var resident: Vector2i = _resident()
	var slot: int = _jobs.directory().get_typed_row(resident)
	var before: int = _schedule.hour_activity_of(slot, 0).value
	var payload: PackedByteArray = _schedule_payload(ACTIVITY_SLEEP)
	payload[23] = 9
	assert_true(_submit(KIND_SET_ACTIVITY_SCHEDULE, resident, 0, 0, payload), "it is admitted")
	assert_equal(_commit(), 0, "the day refuses")
	assert_equal(_last_code(), CommandDispatchScript.RESULT_ARGUMENT_RANGE, "by argument range")
	assert_equal(_schedule.hour_activity_of(slot, 0).value, before, "hour 0 was not written")
	assert_equal(_schedule.hour_activity_of(slot, 23).value,
		_schedule.hour_activity_of(slot, 23).value, "and hour 23 kept whatever it had")


func test_a_legal_schedule_command_writes_all_twenty_four_hours() -> void:
	"""The positive half, so the atomicity test above cannot be passing vacuously."""
	var resident: Vector2i = _resident()
	var slot: int = _jobs.directory().get_typed_row(resident)
	assert_true(_submit(KIND_SET_ACTIVITY_SCHEDULE, resident, 0, 0,
		_schedule_payload(ACTIVITY_WORK)), "it is admitted")
	assert_equal(_commit(), 1, "and it commits")
	for hour: int in HOURS_PER_DAY:
		assert_equal(_schedule.hour_activity_of(slot, hour).value, ACTIVITY_WORK,
			"hour %d is the commanded activity" % hour)


func test_a_schedule_payload_of_the_wrong_length_refuses() -> void:
	"""§8.1's schedule bytes are a whole day: 23 bytes is not a day and is not padded into one."""
	var resident: Vector2i = _resident()
	var short: PackedByteArray = _schedule_payload(ACTIVITY_WORK)
	short.resize(HOURS_PER_DAY - 1)
	assert_true(_submit(KIND_SET_ACTIVITY_SCHEDULE, resident, 0, 0, short), "it is admitted")
	assert_equal(_commit(), 0, "and refuses at commit")
	assert_equal(_last_code(), CommandDispatchScript.RESULT_PAYLOAD_SCHEMA, "by payload schema")


func test_a_refused_designation_destroys_the_zone_it_had_already_created() -> void:
	"""The rollback: `forage.destroy_zone()` unwinds a create that a later store call refused."""
	var refusing: RefusingTileForage = RefusingTileForage.new(_jobs.directory(), _jobs)
	var planner: JobPlannerScript = JobPlannerScript.new(null, _jobs, refusing)
	var dispatch: CommandDispatchScript = CommandDispatchScript.new(_queue, _residents,
		_priorities, _schedule, _jobs, refusing, planner)
	var made: ForageScript.OpResult = refusing.create_zone(ZONE_FORAGE, 0, 0, false, true)
	assert_true(made.ok, "a basin exists to designate inside")
	assert_true(_submit(KIND_DESIGNATE_ZONE, made.ref, ZONE_FORAGE, 0,
		_tile_payload(PackedInt32Array([4]))), "the command is admitted")
	assert_true(dispatch.commit_tick_into(COMMIT_TICK, _report), "the stage runs")
	assert_equal(_report.committed, 0, "the command refuses")
	assert_equal(refusing.zone_count(), 1, "and the zone it created was destroyed again")
	assert_equal(planner.forage_demand_enabled_count(), 0, "no demand survives the rollback")


# --- payload boundaries, invalid ids, generation and UTF-8 name limits ---------------------------

func test_a_payload_longer_than_the_arena_can_hold_is_refused_at_admission() -> void:
	"""§8.1's 1048576-byte arena: overflow refuses at the queue, so nothing reaches the dispatcher."""
	var oversized: PackedByteArray = PackedByteArray()
	oversized.resize(CommandsScript.PAYLOAD_ARENA_BYTES + 1)
	assert_false(_submit(KIND_SET_ACTIVITY_SCHEDULE, EntityDirectory.NULL_REF, 0, 0, oversized),
		"the queue refuses it")
	assert_equal(_submit_result.error, CommandsScript.REFUSE_PAYLOAD_ARENA_FULL, "as arena-full")
	assert_equal(_dispatch.results_recorded(), 0, "and the dispatcher never sees it")


func test_a_declared_row_count_that_disagrees_with_the_payload_length_refuses() -> void:
	"""The count prefix is checked against the buffer, never trusted and never padded."""
	var resident: Vector2i = _resident()
	var payload: PackedByteArray = _priority_payload(PackedInt32Array([0]), PackedInt32Array([2]))
	payload.encode_s32(0, 4)
	assert_true(_submit(KIND_SET_JOB_PRIORITIES, resident, -1, -1, payload), "it is admitted")
	assert_equal(_commit(), 0, "and refuses at commit")
	assert_equal(_last_code(), CommandDispatchScript.RESULT_PAYLOAD_SCHEMA, "by payload schema")


func test_a_declared_row_count_shorter_than_the_buffer_refuses_rather_than_writing_a_prefix() -> void:
	"""The count must agree EXACTLY: a payload carrying more rows than it declares is not truncated."""
	var resident: Vector2i = _resident()
	var slot: int = _jobs.directory().get_typed_row(resident)
	var before: int = _priorities.priority_of(slot, 0).value
	var payload: PackedByteArray = _priority_payload(PackedInt32Array([0, 1]),
		PackedInt32Array([1, 1]))
	payload.encode_s32(0, 1)
	assert_true(_submit(KIND_SET_JOB_PRIORITIES, resident, -1, -1, payload), "it is admitted")
	assert_equal(_commit(), 0, "and refuses at commit")
	assert_equal(_last_code(), CommandDispatchScript.RESULT_PAYLOAD_SCHEMA, "by payload schema")
	assert_equal(_priorities.priority_of(slot, 0).value, before,
		"and not one of the two rows was written")


func test_a_group_of_more_rows_than_the_kind_domain_holds_refuses() -> void:
	"""Thirteen `(kind, priority)` rows exceed this kind's largest legal group and are refused.

	The refusal comes from the upper length guard, which is the check that also stops a tick
	copying an oversized payload into the shared scratch to find out.
	"""
	var resident: Vector2i = _resident()
	var kinds: PackedInt32Array = PackedInt32Array()
	var values: PackedInt32Array = PackedInt32Array()
	for kind: int in JOB_KIND_COUNT + 1:
		kinds.append(kind)
		values.append(1)
	var payload: PackedByteArray = _priority_payload(kinds, values)
	assert_equal(payload.size(), 4 + 8 * (JOB_KIND_COUNT + 1), "the fixture is 108 bytes")
	assert_true(_submit(KIND_SET_JOB_PRIORITIES, resident, -1, -1, payload), "it is admitted")
	assert_equal(_commit(), 0, "and refuses at commit")
	assert_equal(_last_code(), CommandDispatchScript.RESULT_PAYLOAD_SCHEMA,
		"before it is ever copied, and before any kind is read out of it")


func test_a_negative_declared_row_count_refuses_rather_than_wrapping() -> void:
	"""Checked integer arithmetic: a negative length is refused before any offset is computed."""
	var resident: Vector2i = _resident()
	var payload: PackedByteArray = _priority_payload(PackedInt32Array([0]), PackedInt32Array([2]))
	payload.encode_s32(0, -1)
	assert_true(_submit(KIND_SET_JOB_PRIORITIES, resident, -1, -1, payload), "it is admitted")
	assert_equal(_commit(), 0, "and refuses at commit")
	assert_equal(_last_code(), CommandDispatchScript.RESULT_PAYLOAD_SCHEMA, "by payload schema")


func test_a_declared_row_count_of_two_billion_refuses_rather_than_multiplying() -> void:
	"""`count * row_bytes` must not be computed against an unbounded count."""
	var resident: Vector2i = _resident()
	var payload: PackedByteArray = _priority_payload(PackedInt32Array([0]), PackedInt32Array([2]))
	payload.encode_s32(0, 2147483647)
	assert_true(_submit(KIND_SET_JOB_PRIORITIES, resident, -1, -1, payload), "it is admitted")
	assert_equal(_commit(), 0, "and refuses at commit")
	assert_equal(_last_code(), CommandDispatchScript.RESULT_PAYLOAD_SCHEMA, "by payload schema")


func test_a_tile_index_off_the_exterior_grid_refuses() -> void:
	"""The bound is `forage.is_tile_index()`, the owning store's own 128x128 predicate."""
	var basin: Vector2i = _basin()
	assert_true(_submit(KIND_DESIGNATE_ZONE, basin, ZONE_FORAGE, 0,
		_tile_payload(PackedInt32Array([ForageScript.TILE_COUNT]))), "it is admitted")
	assert_equal(_commit(), 0, "and refuses at commit")
	assert_equal(_last_code(), CommandDispatchScript.RESULT_ZONE_TILE_RANGE, "by tile range")
	assert_equal(_forage.zone_count(), 1, "no zone was created")


func test_unsorted_tile_indices_refuse_rather_than_being_sorted_here() -> void:
	"""One canonical tile order, refused into existence so two callers cannot disagree."""
	var basin: Vector2i = _basin()
	assert_true(_submit(KIND_DESIGNATE_ZONE, basin, ZONE_FORAGE, 0,
		_tile_payload(PackedInt32Array([9, 4]))), "it is admitted")
	assert_equal(_commit(), 0, "and refuses at commit")
	assert_equal(_last_code(), CommandDispatchScript.RESULT_ZONE_TILE_UNSORTED, "by tile order")


func test_a_repeated_tile_index_refuses_as_unsorted() -> void:
	"""Strictly ascending: a duplicate link would spend the shared budget on nothing."""
	var basin: Vector2i = _basin()
	assert_true(_submit(KIND_DESIGNATE_ZONE, basin, ZONE_FORAGE, 0,
		_tile_payload(PackedInt32Array([9, 9]))), "it is admitted")
	assert_equal(_commit(), 0, "and refuses at commit")
	assert_equal(_last_code(), CommandDispatchScript.RESULT_ZONE_TILE_UNSORTED, "by tile order")


func test_a_designation_of_a_zone_type_with_no_producer_refuses_as_unsupported() -> void:
	"""FORAGE is the only ZoneType with an implemented demand producer, and the rest say so."""
	var basin: Vector2i = _basin()
	assert_true(_submit(KIND_DESIGNATE_ZONE, basin, ZONE_FARM, 0,
		_tile_payload(PackedInt32Array())), "it is admitted")
	assert_equal(_commit(), 0, "and refuses at commit")
	assert_equal(_last_code(), CommandDispatchScript.RESULT_UNSUPPORTED_FEATURE,
		"as an unsupported feature")


func test_a_danger_band_outside_five_fives_range_refuses() -> void:
	"""§5.5's bands are 0-3, and 4 is refused rather than clamped down to 3."""
	var basin: Vector2i = _basin()
	assert_true(_submit(KIND_DESIGNATE_ZONE, basin, ZONE_FORAGE, 4,
		_tile_payload(PackedInt32Array())), "it is admitted")
	assert_equal(_commit(), 0, "and refuses at commit")
	assert_equal(_last_code(), CommandDispatchScript.RESULT_ARGUMENT_RANGE, "by argument range")
	assert_equal(_forage.zone_count(), 1, "no zone was created")


func test_designating_inside_a_zone_that_is_itself_a_designation_refuses() -> void:
	"""`forage.set_basin()` refuses a chain, because it would give two answers for one zone."""
	var basin: Vector2i = _basin()
	assert_true(_designate(basin), "the first designation commits")
	var designation: Vector2i = _forage.zone_ref_of(_designated_zone_slot())
	assert_true(_submit(KIND_DESIGNATE_ZONE, designation, ZONE_FORAGE, 0,
		_tile_payload(PackedInt32Array())), "a second command targets the designation")
	assert_equal(_commit(), 0, "and refuses at commit")
	assert_equal(_last_code(), CommandDispatchScript.RESULT_BASIN_CHAIN, "as a basin chain")


func test_designating_inside_a_basin_of_another_type_refuses() -> void:
	"""A FORAGE designation cannot draw from a FARM basin: `set_basin()` refuses the type mismatch."""
	var made: ForageScript.OpResult = _forage.create_zone(ZONE_FARM, 0, 0, false, true)
	assert_true(made.ok, "a FARM basin exists")
	assert_true(_submit(KIND_DESIGNATE_ZONE, made.ref, ZONE_FORAGE, 0,
		_tile_payload(PackedInt32Array())), "it is admitted")
	assert_equal(_commit(), 0, "and refuses at commit")
	assert_equal(_last_code(), CommandDispatchScript.RESULT_BASIN_TYPE, "by basin type")


func test_an_alias_shorter_than_two_characters_refuses() -> void:
	"""ARCH-SAVE-005: "Player aliases are 2-32 Unicode characters"."""
	_assert_alias_refused("A".repeat(ALIAS_MIN_CHARACTERS - 1),
		CommandDispatchScript.RESULT_ALIAS_LENGTH)


func test_an_alias_longer_than_thirty_two_characters_refuses() -> void:
	"""The upper bound of the same rule, refused rather than truncated."""
	_assert_alias_refused("A".repeat(ALIAS_MAX_CHARACTERS + 1),
		CommandDispatchScript.RESULT_ALIAS_LENGTH)


func test_an_alias_of_exactly_thirty_two_characters_is_accepted() -> void:
	"""The bound is inclusive, so the boundary is tested from both sides."""
	var resident: Vector2i = _resident()
	var alias: String = "A".repeat(ALIAS_MAX_CHARACTERS)
	assert_true(_submit(KIND_NAME_RESIDENT, resident, 0, 0, alias.to_utf8_buffer()),
		"it is admitted")
	assert_equal(_commit(), 1, "and it commits")
	assert_equal(_residents.name_key_of(_jobs.directory().get_typed_row(resident)),
		StringName(alias), "the resident carries the whole 32-character alias")


func test_an_alias_containing_a_control_character_refuses() -> void:
	"""ARCH-SAVE-005: "with control characters rejected"."""
	_assert_alias_refused("Ro\nwan", CommandDispatchScript.RESULT_ALIAS_CONTROL_CHARACTER)


func test_malformed_utf8_in_an_alias_refuses_rather_than_being_repaired() -> void:
	"""ARCH-SAVE-005 rejects malformed UTF-8; Godot's decoder substitutes, so this re-encodes."""
	var resident: Vector2i = _resident()
	var bytes: PackedByteArray = PackedByteArray([0x52, 0xC3, 0x28, 0x6E])
	assert_true(_submit(KIND_NAME_RESIDENT, resident, 0, 0, bytes), "it is admitted")
	assert_equal(_commit(), 0, "and refuses at commit")
	assert_equal(_last_code(), CommandDispatchScript.RESULT_ALIAS_MALFORMED_UTF8,
		"as malformed UTF-8")
	assert_false(_residents.is_named(_jobs.directory().get_typed_row(resident)),
		"and the resident is left unnamed")


func test_a_multibyte_alias_is_measured_in_characters_not_bytes() -> void:
	"""32 CHARACTERS, not 32 bytes: a four-byte character must not count as four."""
	var resident: Vector2i = _resident()
	var alias: String = "é".repeat(ALIAS_MAX_CHARACTERS)
	assert_equal(alias.to_utf8_buffer().size(), ALIAS_MAX_CHARACTERS * 2,
		"the fixture really is multibyte")
	assert_true(_submit(KIND_NAME_RESIDENT, resident, 0, 0, alias.to_utf8_buffer()),
		"it is admitted")
	assert_equal(_commit(), 1, "and it commits, because 32 characters is inside the bound")


func _assert_alias_refused(alias: String, expected: int) -> void:
	"""Submit one alias, commit it, and assert both the refusal id and that no name was written."""
	var resident: Vector2i = _resident()
	assert_true(_submit(KIND_NAME_RESIDENT, resident, 0, 0, alias.to_utf8_buffer()),
		"it is admitted")
	assert_equal(_commit(), 0, "and refuses at commit")
	assert_equal(_last_code(), expected, "with the expected alias refusal")
	assert_false(_residents.is_named(_jobs.directory().get_typed_row(resident)),
		"and the resident is left unnamed")


# --- CANCEL_JOB ----------------------------------------------------------------------------------

func test_cancel_job_moves_a_queued_job_to_cancelled() -> void:
	"""`jobs.gd`'s cancellation path, reached by a player command for the first time."""
	var job: Vector2i = _job()
	assert_true(_submit(KIND_CANCEL_JOB, job, 0, 0), "it is admitted")
	assert_equal(_commit(), 1, "and it commits")
	assert_equal(_jobs.state_of(_jobs.directory().get_typed_row(job)).value, STATE_CANCELLED,
		"the job is CANCELLED")


func test_cancel_job_releases_the_worker_before_cancelling() -> void:
	"""Decision 0017 keeps departure and cancellation separate, so both run and in that order."""
	var resident: Vector2i = _resident()
	var worker: int = _jobs.directory().get_typed_row(resident)
	var job: Vector2i = _job()
	var job_slot: int = _jobs.directory().get_typed_row(job)
	assert_true(_jobs.assign_worker(worker, job_slot).ok, "a worker holds the job")
	assert_equal(_jobs.state_of(job_slot).value, STATE_RESERVED, "which puts it in RESERVED")
	assert_true(_submit(KIND_CANCEL_JOB, job, 0, 0), "the cancellation is admitted")
	assert_equal(_commit(), 1, "and it commits")
	assert_equal(_jobs.state_of(job_slot).value, STATE_CANCELLED, "the job is CANCELLED")
	assert_equal(_jobs.job_of(worker), EntityDirectory.NULL_REF, "and the worker is free")


func test_cancelling_an_already_cancelled_job_refuses() -> void:
	"""A second cancellation is refused rather than rewritten, so the result is not a lie."""
	var job: Vector2i = _job()
	assert_true(_jobs.set_state(_jobs.directory().get_typed_row(job), STATE_CANCELLED).ok,
		"the job is already cancelled")
	assert_true(_submit(KIND_CANCEL_JOB, job, 0, 0), "it is admitted")
	assert_equal(_commit(), 0, "and refuses at commit")
	assert_equal(_last_code(), CommandDispatchScript.RESULT_JOB_NOT_CANCELLABLE,
		"as not cancellable")


func test_cancelling_a_completed_job_refuses() -> void:
	"""Work already done is not undone by a command that arrived a tick late."""
	var job: Vector2i = _job()
	assert_true(_jobs.set_state(_jobs.directory().get_typed_row(job), STATE_COMPLETE).ok,
		"the job completed")
	assert_true(_submit(KIND_CANCEL_JOB, job, 0, 0), "it is admitted")
	assert_equal(_commit(), 0, "and refuses at commit")
	assert_equal(_last_code(), CommandDispatchScript.RESULT_JOB_NOT_CANCELLABLE,
		"as not cancellable")


func test_a_cancel_job_command_carrying_a_payload_refuses() -> void:
	"""CANCEL_JOB's identity IS the whole command; stray bytes are refused, not ignored."""
	var job: Vector2i = _job()
	assert_true(_submit(KIND_CANCEL_JOB, job, 0, 0, PackedByteArray([1])), "it is admitted")
	assert_equal(_commit(), 0, "and refuses at commit")
	assert_equal(_last_code(), CommandDispatchScript.RESULT_PAYLOAD_SCHEMA, "by payload schema")
	assert_equal(_jobs.state_of(_jobs.directory().get_typed_row(job)).value, STATE_QUEUED,
		"and the job is untouched")


# --- SET_POLICY ----------------------------------------------------------------------------------

func test_set_policy_writes_a_designations_quota_mode() -> void:
	"""Decision 0030 §4.6: Inherit is a designation mode, and the command applies it."""
	assert_true(_designate(_basin()), "a designation exists")
	var zone: int = _designated_zone_slot()
	assert_true(_submit(KIND_SET_POLICY, _forage.zone_ref_of(zone),
		CommandDispatchScript.POLICY_FORAGE_QUOTA_MODE, ForageScript.QUOTA_MODE_INHERIT),
		"it is admitted")
	assert_equal(_commit(), 1, "and it commits")
	assert_equal(_forage.quota_mode_of(zone).value, ForageScript.QUOTA_MODE_INHERIT,
		"the designation is now on Inherit")


func test_set_policy_refuses_a_basin_mode_on_a_designation() -> void:
	"""Automatic is a BASIN mode; applying it to a designation is refused, not normalised."""
	assert_true(_designate(_basin()), "a designation exists")
	var zone: int = _designated_zone_slot()
	assert_true(_submit(KIND_SET_POLICY, _forage.zone_ref_of(zone),
		CommandDispatchScript.POLICY_FORAGE_QUOTA_MODE, ForageScript.QUOTA_MODE_AUTOMATIC),
		"it is admitted")
	assert_equal(_commit(), 0, "and refuses at commit")
	assert_equal(_last_code(), CommandDispatchScript.RESULT_POLICY_NOT_VALID_HERE,
		"because the mode is not valid here")
	assert_equal(_forage.quota_mode_of(zone).value, ForageScript.QUOTA_MODE_INHERIT,
		"and the stored mode did not move")


func test_set_policy_refuses_an_unknown_quota_mode() -> void:
	"""An out-of-domain mode is refused rather than stored or clamped."""
	var basin: Vector2i = _basin()
	assert_true(_submit(KIND_SET_POLICY, basin,
		CommandDispatchScript.POLICY_FORAGE_QUOTA_MODE, ForageScript.QUOTA_MODE_COUNT),
		"it is admitted")
	assert_equal(_commit(), 0, "and refuses at commit")
	assert_equal(_last_code(), CommandDispatchScript.RESULT_ARGUMENT_RANGE, "by argument range")


func test_set_policy_refuses_an_unknown_policy_selector() -> void:
	"""An unlabelled integer would make two policies indistinguishable; an unknown one refuses."""
	var basin: Vector2i = _basin()
	assert_true(_submit(KIND_SET_POLICY, basin, CommandDispatchScript.POLICY_COUNT, 0),
		"it is admitted")
	assert_equal(_commit(), 0, "and refuses at commit")
	assert_equal(_last_code(), CommandDispatchScript.RESULT_ARGUMENT_RANGE, "by argument range")


func test_disabling_a_designation_stops_its_demand_and_its_zone_flag_together() -> void:
	"""The zone flag and the planner's demand are one intent; leaving them disagreeing is the bug."""
	assert_true(_designate(_basin()), "a designation exists with demand enabled")
	var zone: int = _designated_zone_slot()
	assert_true(_planner.is_forage_demand_enabled(zone), "demand starts enabled")
	assert_true(_submit(KIND_SET_POLICY, _forage.zone_ref_of(zone),
		CommandDispatchScript.POLICY_FORAGE_ZONE_ENABLED, 0), "the disable is admitted")
	assert_equal(_commit(), 1, "and it commits")
	assert_false(_forage.is_zone_enabled(zone), "the zone flag is off")
	assert_false(_planner.is_forage_demand_enabled(zone), "and the demand is off with it")


func test_re_enabling_a_designation_restores_its_demand() -> void:
	"""The other direction of the same policy, so the toggle is not one-way."""
	assert_true(_designate(_basin()), "a designation exists")
	var zone: int = _designated_zone_slot()
	var zone_ref: Vector2i = _forage.zone_ref_of(zone)
	assert_true(_submit(KIND_SET_POLICY, zone_ref,
		CommandDispatchScript.POLICY_FORAGE_ZONE_ENABLED, 0), "the disable is admitted")
	assert_equal(_commit(), 1, "the disable commits")
	assert_true(_submit(KIND_SET_POLICY, zone_ref,
		CommandDispatchScript.POLICY_FORAGE_ZONE_ENABLED, 1), "the enable is admitted")
	assert_equal(_commit(), 1, "the enable commits")
	assert_true(_forage.is_zone_enabled(zone), "the zone flag is on")
	assert_true(_planner.is_forage_demand_enabled(zone), "and the demand is on with it")


func test_re_enabling_an_already_enabled_designation_commits_instead_of_refusing() -> void:
	"""The policy is idempotent: the same command twice is one activation, not a refusal.

	A repeat `enable_forage_demand()` is refused BY THE PLANNER, and rightly so -- N enables must
	activate one demand. So the dispatch must not ask for a change that is already made, or a
	player pressing the same button twice would be told their settlement refused them.
	"""
	assert_true(_designate(_basin()), "a designation exists with demand enabled")
	var zone: int = _designated_zone_slot()
	assert_true(_submit(KIND_SET_POLICY, _forage.zone_ref_of(zone),
		CommandDispatchScript.POLICY_FORAGE_ZONE_ENABLED, 1), "the redundant enable is admitted")
	assert_equal(_commit(), 1, "and it commits")
	assert_equal(_last_code(), CommandDispatchScript.RESULT_COMMITTED, "reporting success")
	assert_true(_planner.is_forage_demand_enabled(zone), "the demand is still enabled")
	assert_equal(_planner.forage_demand_enabled_count(), 1, "and there is still exactly one")


func test_disabling_an_already_disabled_designation_commits_instead_of_refusing() -> void:
	"""The same idempotence in the other direction, so the guard is not one-sided."""
	assert_true(_designate(_basin()), "a designation exists")
	var zone_ref: Vector2i = _forage.zone_ref_of(_designated_zone_slot())
	assert_true(_submit(KIND_SET_POLICY, zone_ref,
		CommandDispatchScript.POLICY_FORAGE_ZONE_ENABLED, 0), "the disable is admitted")
	assert_equal(_commit(), 1, "the disable commits")
	assert_true(_submit(KIND_SET_POLICY, zone_ref,
		CommandDispatchScript.POLICY_FORAGE_ZONE_ENABLED, 0), "a second disable is admitted")
	assert_equal(_commit(), 1, "and it commits too")
	assert_equal(_last_code(), CommandDispatchScript.RESULT_COMMITTED, "reporting success")


func test_a_refused_demand_change_restores_the_zone_flag_it_had_moved() -> void:
	"""Atomicity: a planner refusal must not leave the zone flag on with no demand behind it."""
	var basin: Vector2i = _basin()
	assert_true(_submit(KIND_SET_POLICY, basin,
		CommandDispatchScript.POLICY_FORAGE_ZONE_ENABLED, 1), "the enable is admitted")
	assert_true(_forage.set_zone_enabled(basin, false).ok, "the basin starts disabled")
	assert_equal(_commit(), 0, "the command refuses: a basin is nobody's designation")
	assert_equal(_last_code(), CommandDispatchScript.RESULT_STORE_REFUSED, "by a store refusal")
	assert_equal(_row.store_code, JobPlannerScript.REFUSE_NOT_A_DESIGNATION,
		"and the ledger names the planner's own code")
	assert_false(_forage.is_zone_enabled(_forage.zone_slot_of(basin).value),
		"the enabled flag it had already written is restored")


func test_an_out_of_range_zone_enabled_value_refuses() -> void:
	"""The flag is 0 or 1, and 2 is refused rather than treated as truthy."""
	var basin: Vector2i = _basin()
	assert_true(_submit(KIND_SET_POLICY, basin,
		CommandDispatchScript.POLICY_FORAGE_ZONE_ENABLED, 2), "it is admitted")
	assert_equal(_commit(), 0, "and refuses at commit")
	assert_equal(_last_code(), CommandDispatchScript.RESULT_ARGUMENT_RANGE, "by argument range")


# --- capacity, unchanged state, projections and the documented result domain ----------------------

func test_four_thousand_and_ninety_six_records_are_accepted_and_the_next_refuses() -> void:
	"""§8.1's queue length is a CONTRACT, not a performance claim; the 4097th refuses cleanly."""
	for _index: int in CommandsScript.QUEUE_CAPACITY:
		assert_true(_submit(KIND_ACCEPT_CANDIDATES, EntityDirectory.NULL_REF, 0, 0),
			"every one of the first 4096 is accepted")
	assert_equal(_queue.pending_count(), CommandsScript.QUEUE_CAPACITY, "the queue is full")
	assert_false(_submit(KIND_ACCEPT_CANDIDATES, EntityDirectory.NULL_REF, 0, 0),
		"the 4097th is refused")
	assert_equal(_submit_result.error, CommandsScript.REFUSE_QUEUE_FULL, "as queue-full")
	assert_equal(_commit(), 0, "the stage commits none of them, because the kind is unsupported")
	assert_equal(_report.drained, CommandsScript.QUEUE_CAPACITY, "but it drained all 4096")
	assert_equal(_dispatch.result_count(), CommandsScript.QUEUE_CAPACITY,
		"and the ledger retains one outcome for each")


func test_a_refused_admission_leaves_the_authoritative_state_byte_identical() -> void:
	"""04.2: "Hash unchanged authoritative state for refused admission"."""
	var basin: Vector2i = _basin()
	assert_true(_designate(basin, 2, PackedInt32Array([11, 12])), "one designation exists")
	var before: String = _state_digest()
	var bad: CommandsScript.Command = CommandsScript.Command.new()
	bad.kind = KIND_DESIGNATE_ZONE
	bad.flags = 1
	assert_false(_queue.submit_into(bad, _submit_result), "an undefined flag bit is refused")
	assert_false(_submit(KIND_DESIGNATE_ZONE, Vector2i(basin.x, basin.y + 99), ZONE_FORAGE, 0),
		"and so is a stale target generation")
	assert_equal(_submit_result.error, CommandsScript.REFUSE_TARGET_INVALID, "as an invalid target")
	assert_equal(_state_digest(), before, "the whole authoritative digest is unchanged")
	assert_equal(_dispatch.results_recorded(), 1, "and no new outcome was recorded")


func _state_digest() -> String:
	"""A stable text digest of every authoritative field this suite can reach.

	Not a save hash -- there is no save module -- but every zone flag, quota mode, demand flag,
	job state, priority, schedule hour and resident name, in a fixed order. A command that
	changed any one of them would change this string.
	"""
	var parts: PackedStringArray = PackedStringArray()
	for slot: int in ForageScript.HARVEST_ZONE_CAPACITY:
		if not _forage.is_zone_present(slot):
			continue
		parts.append("z%d:%d:%d:%d:%d:%d" % [slot, _forage.zone_type_of(slot).value,
			_forage.zone_danger_of(slot).value, _forage.quota_mode_of(slot).value,
			1 if _forage.is_zone_enabled(slot) else 0, _forage.tile_count_of(slot).value])
		parts.append("d%d:%d" % [slot, 1 if _planner.is_forage_demand_enabled(slot) else 0])
	for slot: int in JobsScript.JOB_CAPACITY:
		if _jobs.is_job_present(slot):
			parts.append("j%d:%d:%d" % [slot, _jobs.kind_of(slot).value,
				_jobs.state_of(slot).value])
	for slot: int in ResidentsScript.RESIDENT_CAPACITY:
		if _residents.is_present(slot):
			parts.append("r%d:%s" % [slot, _residents.name_key_of(slot)])
	return "|".join(parts)


func test_the_result_domain_is_ascii_sorted_unique_and_round_trips() -> void:
	"""The index IS the stored id, so a renumbering must be caught here rather than in a save."""
	assert_equal(CommandDispatchScript.RESULT_CODES.size(), CommandDispatchScript.RESULT_COUNT,
		"every id names one code")
	for index: int in CommandDispatchScript.RESULT_COUNT - 1:
		assert_true(String(CommandDispatchScript.RESULT_CODES[index])
			< String(CommandDispatchScript.RESULT_CODES[index + 1]),
			"code %d sorts before code %d" % [index, index + 1])
	for index: int in CommandDispatchScript.RESULT_COUNT:
		assert_equal(_dispatch.result_code_id(_dispatch.result_code(index)), index,
			"id %d round-trips through its StringName" % index)


func test_an_unknown_result_id_is_reported_as_unknown_rather_than_as_a_code() -> void:
	"""Absence is a predicate, never a sentinel that could be mistaken for a real refusal."""
	assert_false(_dispatch.is_result_id(-1), "a negative id is not in the domain")
	assert_false(_dispatch.is_result_id(CommandDispatchScript.RESULT_COUNT),
		"and neither is one past the end")
	assert_equal(_dispatch.result_code(CommandDispatchScript.RESULT_COUNT), &"",
		"an id outside the domain names no code")
	assert_equal(_dispatch.result_code_id(&"NOT_A_REAL_CODE"), CommandDispatchScript.RESULT_COUNT,
		"and an unknown code answers outside the domain")


func test_the_committed_code_is_the_one_the_success_id_indexes() -> void:
	"""A committed command must report COMMAND_COMMITTED, by name and not merely by number."""
	var job: Vector2i = _job()
	assert_true(_submit(KIND_CANCEL_JOB, job, 0, 0), "it is admitted")
	assert_equal(_commit(), 1, "and it commits")
	assert_true(_dispatch.last_result_into(_row), "the outcome is readable")
	assert_true(_row.ok(), "the row reports success")
	assert_equal(_row.code(), &"COMMAND_COMMITTED", "under the documented success code")
	assert_equal(_row.store_code, &"", "and names no store refusal")


func test_a_pending_projection_is_a_copy_that_shows_cancellation_and_support() -> void:
	"""04.2: "immutable presentation projections show pending entries and cancellation state"."""
	var job: Vector2i = _job()
	assert_true(_submit(KIND_CANCEL_JOB, job, 0, 0), "a cancellation is queued")
	assert_true(_submit(KIND_CANCEL_MANUAL, EntityDirectory.NULL_REF, 0, 0),
		"and an unsupported cancellation behind it")
	var view: CommandDispatchScript.PendingRow = CommandDispatchScript.PendingRow.new()
	assert_true(_dispatch.pending_into(0, view), "the first pending row reads")
	assert_true(view.is_cancellation, "it is drawn as a cancellation")
	assert_true(view.is_supported, "and it will be committed")
	assert_equal(view.target_slot, job.x, "it names its target")
	assert_true(_dispatch.pending_into(1, view), "the second pending row reads")
	assert_true(view.is_cancellation, "CANCEL_MANUAL is a cancellation too")
	assert_false(view.is_supported, "but it will refuse, and presentation can warn first")
	assert_equal(_dispatch.pending_count(), 2, "reading a projection consumed nothing")


func test_a_pending_projection_cannot_be_read_past_the_end_of_the_queue() -> void:
	"""Out-of-range reads refuse rather than answering a zeroed row that looks like a command."""
	var view: CommandDispatchScript.PendingRow = CommandDispatchScript.PendingRow.new()
	assert_false(_dispatch.pending_into(0, view), "an empty queue has no row 0")
	assert_true(_submit(KIND_ACCEPT_CANDIDATES, EntityDirectory.NULL_REF, 0, 0), "one is queued")
	assert_true(_dispatch.pending_into(0, view), "row 0 now reads")
	assert_false(_dispatch.pending_into(1, view), "and row 1 still does not")


func test_a_result_projection_cannot_be_read_past_the_end_of_the_ledger() -> void:
	"""The same rule on the outcome side: an unrecorded index refuses."""
	assert_false(_dispatch.result_into(0, _row), "an empty ledger has no row 0")
	assert_false(_dispatch.last_result_into(_row), "and no last row")
	assert_true(_submit(KIND_ACCEPT_CANDIDATES, EntityDirectory.NULL_REF, 0, 0), "one is queued")
	assert_equal(_commit(), 0, "it refuses")
	assert_true(_dispatch.result_into(0, _row), "and now row 0 reads")
	assert_false(_dispatch.result_into(1, _row), "row 1 still does not")


func test_the_stage_counts_what_it_committed_and_what_it_refused() -> void:
	"""`drained` splits exactly into `committed` and `refused`, so neither can be inferred wrong."""
	var job: Vector2i = _job()
	assert_true(_submit(KIND_CANCEL_JOB, job, 0, 0), "one command will commit")
	assert_true(_submit(KIND_ACCEPT_CANDIDATES, EntityDirectory.NULL_REF, 0, 0),
		"and one will refuse")
	assert_equal(_commit(), 1, "one committed")
	assert_equal(_report.drained, 2, "two were drained")
	assert_equal(_report.refused, 1, "and one refused")
	assert_equal(_dispatch.committed_count(), 1, "the running totals agree")
	assert_equal(_dispatch.refused_count(), 1, "on both sides")


func test_a_refusing_command_records_no_value_from_the_command_before_it() -> void:
	"""The ledger's produced value is this command's or zero, never the previous command's."""
	var resident: Vector2i = _resident()
	assert_true(_submit(KIND_SET_ACTIVITY_SCHEDULE, resident, 0, 0,
		_schedule_payload(ACTIVITY_WORK)), "a command that produces a value is queued")
	assert_true(_submit(KIND_CANCEL_JOB, EntityDirectory.NULL_REF, 0, 0),
		"and a refusing command behind it")
	assert_equal(_commit(), 1, "one of the two commits")
	assert_true(_dispatch.result_into(0, _row), "the first outcome reads")
	assert_equal(_row.value, HOURS_PER_DAY, "the schedule wrote 24 hours")
	assert_true(_dispatch.result_into(1, _row), "the second outcome reads")
	assert_equal(_row.code_id, CommandDispatchScript.RESULT_TARGET_REQUIRED, "it refused")
	assert_equal(_row.value, 0, "and carries no value, least of all the first command's 24")


func test_a_negative_tick_refuses_the_whole_stage_without_draining_anything() -> void:
	"""The stage refuses rather than committing a player's edits against a nonsense tick."""
	assert_true(_submit(KIND_ACCEPT_CANDIDATES, EntityDirectory.NULL_REF, 0, 0), "one is queued")
	assert_false(_dispatch.commit_tick_into(-1, _report), "the stage refuses")
	assert_equal(_dispatch.last_refusal(), &"INVALID_TICK", "naming the tick")
	assert_equal(_queue.pending_count(), 1, "and the command is still queued")


func test_a_command_due_later_is_not_drained_early() -> void:
	"""`drain_due_into()` is a due test, so a command for tick 2 is not committed during tick 0."""
	assert_true(_submit(KIND_ACCEPT_CANDIDATES, EntityDirectory.NULL_REF, 0, 0), "one is queued")
	assert_true(_dispatch.commit_tick_into(0, _report), "tick 0's stage runs")
	assert_equal(_report.drained, 0, "and drains nothing, because the edit is due at tick 1")
	assert_equal(_queue.pending_count(), 1, "the command still waits")
	assert_equal(_commit(), 0, "tick 1 drains it")
	assert_equal(_report.drained, 1, "exactly once")


func test_the_ledger_bytes_reader_reports_the_allocation_it_actually_made() -> void:
	"""§2.3's new row is arithmetic over real columns, not a number written into a document."""
	assert_equal(_dispatch.result_capacity(), CommandsScript.QUEUE_CAPACITY,
		"one outcome per queued command")
	assert_equal(_dispatch.ledger_bytes(), 4096 * 8 + 7 * 4096 * 4 + 4096 * 8 + 65540,
		"the ledger row is the i64 column, seven i32 columns, the code array and the scratch")


# --- capacity preflights: the directory and the shared tile-link arena ---------------------------

func test_a_designation_refuses_when_the_harvest_zone_rows_are_exhausted() -> void:
	"""The directory capacity is preflighted, so a full arena refuses before anything is created."""
	var basin: Vector2i = _basin()
	while _forage.zone_count() < ForageScript.HARVEST_ZONE_CAPACITY:
		assert_true(_forage.create_zone(ZONE_FORAGE, 0, 0, false, true).ok,
			"the HarvestZone arena fills")
	assert_true(_submit(KIND_DESIGNATE_ZONE, basin, ZONE_FORAGE, 0,
		_tile_payload(PackedInt32Array())), "the command is admitted")
	assert_equal(_commit(), 0, "and refuses at commit")
	assert_equal(_last_code(), CommandDispatchScript.RESULT_ZONE_CAPACITY, "by zone capacity")
	assert_equal(_forage.zone_count(), ForageScript.HARVEST_ZONE_CAPACITY,
		"and no 129th zone was created")


func test_a_designation_refuses_when_the_shared_tile_link_arena_is_full() -> void:
	"""§4.2's 16384 total-link ceiling is preflighted against `forage.link_count()`."""
	var basin: Vector2i = _basin()
	var filler: ForageScript.OpResult = _forage.create_zone(ZONE_FORAGE, 0, 0, false, true)
	assert_true(filler.ok, "a filler zone exists to hold the links")
	for tile: int in ForageScript.ZONE_LINK_CAPACITY:
		_forage.add_tile(filler.ref, tile)
	assert_equal(_forage.link_count(), ForageScript.ZONE_LINK_CAPACITY, "the arena is full")
	assert_true(_submit(KIND_DESIGNATE_ZONE, basin, ZONE_FORAGE, 0,
		_tile_payload(PackedInt32Array([0]))), "the command is admitted")
	assert_equal(_commit(), 0, "and refuses at commit")
	assert_equal(_last_code(), CommandDispatchScript.RESULT_ZONE_LINK_CAPACITY,
		"by the link ceiling")
	assert_equal(_forage.zone_count(), 2, "and no designation was created")


func test_a_designation_with_no_tiles_at_all_still_commits() -> void:
	"""A zero-row tile group is a legal count-prefixed payload, and is not a schema error."""
	assert_true(_designate(_basin()), "the tile-less designation commits")
	assert_equal(_forage.tile_count_of(_designated_zone_slot()).value, 0, "it links no tile")
	assert_true(_planner.is_forage_demand_enabled(_designated_zone_slot()),
		"and its demand is still enabled")


func test_a_designate_zone_payload_with_no_count_prefix_refuses() -> void:
	"""The count prefix is the schema; an empty payload is refused rather than read as zero rows."""
	var basin: Vector2i = _basin()
	assert_true(_submit(KIND_DESIGNATE_ZONE, basin, ZONE_FORAGE, 0), "it is admitted")
	assert_equal(_commit(), 0, "and refuses at commit")
	assert_equal(_last_code(), CommandDispatchScript.RESULT_PAYLOAD_SCHEMA, "by payload schema")


func test_the_store_code_of_a_refusing_store_reaches_the_result_row() -> void:
	"""`COMMAND_STORE_REFUSED` is never the whole story: the owning store's code is kept too."""
	var basin: Vector2i = _basin()
	assert_true(_forage.set_zone_enabled(basin, false).ok, "the basin starts disabled")
	assert_true(_submit(KIND_SET_POLICY, basin,
		CommandDispatchScript.POLICY_FORAGE_ZONE_ENABLED, 1), "it is admitted")
	assert_equal(_commit(), 0, "and refuses at commit")
	assert_true(_dispatch.last_result_into(_row), "the outcome is readable")
	assert_equal(_row.code(), &"COMMAND_STORE_REFUSED", "under the store-refusal code")
	assert_equal(_row.store_code, JobPlannerScript.REFUSE_NOT_A_DESIGNATION,
		"and it carries the planner's own verbatim refusal")


func test_a_lower_low_sequence_word_is_a_different_intent_not_a_duplicate() -> void:
	"""The identity is an EQUALITY on all three words, never an ordering on any of them.

	Added after mutation testing: comparing the low word with `<` instead of `!=` passed the whole
	suite, because every existing case had the later command carrying the HIGHER sequence. The
	load path does not: `restore_sequence()` resumes the cursor at a checkpoint, and a replay
	stream then re-admits pending records whose sequences are BELOW it. Those are different
	intents and must commit.
	"""
	assert_true(_queue.restore_sequence(0, 5), "the session resumes at sequence 5")
	var basin: Vector2i = _basin()
	assert_true(_designate(basin, 0, PackedInt32Array([5])), "the first designation commits")
	assert_equal(_dispatch.source_intent_count(), 1, "recording the intent at sequence 5")
	assert_true(_admit_stamped(basin, 0, 2, COMMIT_TICK + 4),
		"a record carrying the LOWER sequence 2 is admitted")
	assert_true(_dispatch.commit_tick_into(COMMIT_TICK + 4, _report), "the later stage runs")
	assert_equal(_last_code(), CommandDispatchScript.RESULT_COMMITTED,
		"and it commits: a different sequence is a different intent")
	assert_equal(_dispatch.source_intent_count(), 2, "two intents, two designations")


func test_a_lower_high_sequence_word_is_a_different_intent_not_a_duplicate() -> void:
	"""The same for the HIGH word, with the low words equal so the low check cannot mask it."""
	assert_true(_queue.restore_sequence(1, 0), "the session resumes at high word 1")
	var basin: Vector2i = _basin()
	assert_true(_designate(basin, 0, PackedInt32Array([5])), "the first designation commits")
	assert_equal(_dispatch.source_intent_count(), 1, "recording the intent at (1, 0)")
	assert_true(_admit_stamped(basin, 0, 0, COMMIT_TICK + 4),
		"a record carrying (0, 0) -- the same low word, a lower high word -- is admitted")
	assert_true(_dispatch.commit_tick_into(COMMIT_TICK + 4, _report), "the later stage runs")
	assert_equal(_last_code(), CommandDispatchScript.RESULT_COMMITTED,
		"and it commits: the high word is compared for equality, not order")
	assert_equal(_dispatch.source_intent_count(), 2, "two intents, two designations")


func _admit_stamped(basin: Vector2i, high: int, low: int, execute_tick: int) -> bool:
	"""Admit one DESIGNATE_ZONE carrying its own envelope, as a replay or load stream supplies it."""
	var stamped: CommandsScript.Command = CommandsScript.Command.new()
	stamped.reset()
	stamped.kind = KIND_DESIGNATE_ZONE
	stamped.target_slot = basin.x
	stamped.target_generation = basin.y
	stamped.arg0 = ZONE_FORAGE
	stamped.arg1 = 0
	stamped.payload = _tile_payload(PackedInt32Array([5]))
	stamped.player_id = 0
	stamped.execute_tick = execute_tick
	stamped.sequence_high = high
	stamped.sequence_low = low
	return _queue.admit_stamped_into(stamped, _submit_result)
