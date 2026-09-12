extends "res://test/framework/test_case.gd"
## Coverage for the rule that a UI callback may not write a store: it must produce a command.
##
## Task 04.2: "No UI callback edits resident, ecology, jobs or inventory stores directly." The
## tests below drive the bridge exactly as a panel would and then look at the STORES, which is
## the only place the difference shows up:
##
##   * after a zone designation the HarvestZone store still holds only the basin, the Job store
##     is still empty, and the command is sitting in the queue as pending state;
##   * the stores change only when ARCH-SYS-002's commit stage runs, on a tick;
##   * the job that appears is QUEUED, and stays QUEUED -- `JOB_STATE_WORK` is never written,
##     because no route or arrival exists to justify it.
##
## The clock never advances in this suite, so every submission is a PAUSED edit due at
## `completed_tick + 1`, which is the state 04.4's acceptance walks through.

const UiCommandBridge := preload("res://scripts/ui/ui_command_bridge.gd")
const CommandsScript := preload("res://scripts/core/commands.gd")
const CommandDispatchScript := preload("res://scripts/core/command_dispatch.gd")
const ForageScript := preload("res://scripts/core/forage.gd")
const JobPlannerScript := preload("res://scripts/core/job_planner.gd")
const JobsScript := preload("res://scripts/core/jobs.gd")
const PrioritiesScript := preload("res://scripts/core/priorities.gd")
const ResidentsScript := preload("res://scripts/core/residents.gd")
const ScheduleScript := preload("res://scripts/core/schedule.gd")
const SimClockScript := preload("res://scripts/core/sim_clock.gd")
const EntityDirectoryScript := preload("res://scripts/core/entity_directory.gd")

## ARCH-CMD-003's kind ids, transcribed from the architecture rather than read from catalog.gd.
const KIND_CANCEL_JOB: int = 3
const KIND_DESIGNATE_ZONE: int = 8
const KIND_NAME_RESIDENT: int = 11
const KIND_SET_POLICY: int = 20

## GDD §4.3's JobState numbering, transcribed.
const STATE_QUEUED: int = 0
const STATE_WORK: int = 3
const STATE_CANCELLED: int = 7
const JOB_KIND_FORAGE: int = 4

const ZONE_FORAGE: int = ForageScript.ZONE_TYPE_FORAGE
const PATCH_ITEM_IDS: Array[int] = [10, 11, 12, 13, 14]
const COMMIT_TICK: int = 1
const ORDINARY_PRIORITY: int = 3
const WORK_HOUR: int = 8

var _residents: ResidentsScript = null
var _priorities: PrioritiesScript = null
var _schedule: ScheduleScript = null
var _jobs: JobsScript = null
var _forage: ForageScript = null
var _planner: JobPlannerScript = null
var _clock: SimClockScript = null
var _queue: CommandsScript = null
var _dispatch: CommandDispatchScript = null
var _bridge: UiCommandBridge = null
var _report: CommandDispatchScript.TickReport = null


func before_each() -> void:
	"""Compose one settlement whose stores share a directory, and a bridge over its queue only."""
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
	_bridge = UiCommandBridge.new(_queue)
	_report = CommandDispatchScript.TickReport.new()


func after_each() -> void:
	"""Drop every store so no test inherits another's rows."""
	_bridge = null
	_dispatch = null
	_queue = null
	_planner = null
	_forage = null
	_jobs = null
	_schedule = null
	_priorities = null
	_residents = null
	_report = null


# --- fixture helpers ----------------------------------------------------------------------------

func _basin() -> Vector2i:
	"""A world-generated FORAGE basin with §5.5's five patches. It is nobody's designation."""
	var made: ForageScript.OpResult = _forage.create_zone(ZONE_FORAGE, 0, 0, false, true)
	assert_true(made.ok, "the basin is created (error: %s)" % made.error)
	assert_true(_forage.create_patch_set(made.ref, PackedInt32Array(PATCH_ITEM_IDS)).ok,
		"the basin receives five patches")
	return made.ref


func _resident() -> Vector2i:
	"""One spawned resident with its priorities, schedule and job-agent rows."""
	var spawned: ResidentsScript.OpResult = _residents.spawn(&"mouse")
	assert_true(spawned.ok, "the resident spawns (error: %s)" % spawned.error)
	var slot: int = _residents.directory().get_typed_row(spawned.ref)
	assert_true(_priorities.spawn(slot).ok, "it takes a priorities row")
	assert_true(_schedule.spawn(slot, _schedule.default_template_id().value).ok,
		"it takes a schedule row")
	assert_true(_jobs.spawn_agent(slot).ok, "it takes a job-agent row")
	return spawned.ref


func _commit() -> int:
	"""Run one ARCH-SYS-002 commit stage and return how many commands committed."""
	assert_true(_dispatch.commit_tick_into(COMMIT_TICK, _report),
		"the commit stage runs (error: %s)" % _report.error)
	return _report.committed


func _designated_zone_slot() -> int:
	"""The HarvestZone row of the designation the committed command created."""
	for slot: int in ForageScript.HARVEST_ZONE_CAPACITY:
		if _forage.is_zone_present(slot) and _forage.is_designation(slot):
			return slot
	fail("no designation exists")
	return 0


func _published_harvest() -> int:
	"""The typed Job row of the harvest the designation published, whichever patch kind won.

	Decision 0030's daily quota is aggregate across §5.5's five kinds, so which kind takes the
	allowance belongs to the planner. This asks the planner rather than assuming one.
	"""
	var zone: int = _designated_zone_slot()
	for patch_kind: int in ForageScript.PATCHES_PER_ZONE:
		var ref: Vector2i = _planner.forage_demand_job_of(zone, patch_kind)
		if ref != EntityDirectoryScript.NULL_REF:
			return _jobs.directory().get_typed_row(ref)
	fail("the designation published no harvest")
	return 0


# --- the rule: a player action is a command, not a store write -----------------------------------

func test_a_zone_designation_writes_no_store_until_the_commit_stage_runs() -> void:
	"""The whole point: a UI action produces pending command state and touches nothing."""
	var basin: Vector2i = _basin()
	var zones_before: int = _forage.zone_count()
	assert_true(_bridge.designate_zone(basin, ZONE_FORAGE, 0, PackedInt32Array([5, 6, 7])),
		"the designation is accepted (error: %s)" % _bridge.last_refusal())
	assert_equal(_forage.zone_count(), zones_before, "no zone was created by the UI callback")
	assert_equal(_jobs.job_count(), 0, "and no job was created either")
	assert_equal(_queue.pending_count(), 1, "the command is pending in the queue")
	assert_equal(_bridge.pending_count(), 1, "which the interface reports as pending")


func test_the_pending_command_carries_the_kind_and_target_the_panel_chose() -> void:
	"""A pending entry is inspectable state, not an opaque promise."""
	var basin: Vector2i = _basin()
	assert_true(_bridge.designate_zone(basin, ZONE_FORAGE, 0, PackedInt32Array([9])),
		"the designation is accepted")
	var pending: CommandsScript.Command = CommandsScript.Command.new()
	assert_true(_queue.read_into(0, pending), "the pending record reads back")
	assert_equal(pending.kind, KIND_DESIGNATE_ZONE, "it is a DESIGNATE_ZONE")
	assert_equal(pending.target_slot, basin.x, "aimed at the basin the player picked")
	assert_equal(pending.target_generation, basin.y, "with its generation")
	assert_equal(pending.arg0, ZONE_FORAGE, "and the zone type the brush was set to")


func test_committing_the_command_designates_a_real_zone() -> void:
	"""The store changes on the tick, through ARCH-SYS-002, and not before."""
	var basin: Vector2i = _basin()
	assert_true(_bridge.designate_zone(basin, ZONE_FORAGE, 0, PackedInt32Array([5, 6, 7])),
		"the designation is accepted")
	assert_equal(_commit(), 1, "one command commits")
	assert_equal(_forage.zone_count(), 2, "the basin now has a designation over it")
	assert_true(_forage.is_designation(_designated_zone_slot()), "which is a real designation")


func test_the_committed_designation_produces_one_queued_forage_job() -> void:
	"""04.4's acceptance: resume and observe one real source intent and job."""
	assert_true(_bridge.designate_zone(_basin(), ZONE_FORAGE, 0, PackedInt32Array([5])),
		"the designation is accepted")
	assert_equal(_commit(), 1, "it commits")
	assert_true(_planner.run_tick(COMMIT_TICK).ok, "the ARCH-SYS-009 planner tick runs")
	assert_equal(_jobs.job_count(), 1, "one harvest job exists")
	var harvest: int = _published_harvest()
	assert_equal(_jobs.kind_of(harvest).value, JOB_KIND_FORAGE, "it is a FORAGE job")
	assert_equal(_jobs.state_of(harvest).value, STATE_QUEUED, "and it is QUEUED")


func test_no_ui_action_ever_advances_a_job_to_work() -> void:
	"""Task 04.4: a QUEUED job is the correct visible outcome until task 05 lands routes."""
	assert_true(_bridge.designate_zone(_basin(), ZONE_FORAGE, 0, PackedInt32Array([5])),
		"the designation is accepted")
	assert_equal(_commit(), 1, "it commits")
	assert_true(_planner.run_tick(COMMIT_TICK).ok, "the planner publishes the harvest")
	var harvest: int = _published_harvest()
	for extra: int in 4:
		assert_true(_dispatch.commit_tick_into(COMMIT_TICK + 1 + extra, _report),
			"another commit stage runs")
	assert_equal(_jobs.state_of(harvest).value, STATE_QUEUED, "the harvest is still QUEUED")
	assert_false(_jobs.state_of(harvest).value == STATE_WORK, "never WORK")


func test_cancellation_is_a_command_and_cancels_the_real_job() -> void:
	"""04.4's acceptance ends with a cancellation, which must also travel through the queue."""
	assert_true(_bridge.designate_zone(_basin(), ZONE_FORAGE, 0, PackedInt32Array([5])),
		"the designation is accepted")
	assert_equal(_commit(), 1, "it commits")
	assert_true(_planner.run_tick(COMMIT_TICK).ok, "the planner publishes the harvest")
	var harvest: int = _published_harvest()
	assert_true(_bridge.cancel_job(_jobs.ref_of(harvest)), "the cancellation is accepted")
	assert_equal(_jobs.state_of(harvest).value, STATE_QUEUED, "the job is untouched while pending")
	assert_true(_dispatch.commit_tick_into(COMMIT_TICK + 1, _report), "the next commit stage runs")
	assert_equal(_jobs.state_of(harvest).value, STATE_CANCELLED, "and now it is CANCELLED")


func test_a_policy_toggle_is_a_command_not_a_store_flag_flip() -> void:
	"""UI-SET-100's work policy reaches `forage.gd` only through SET_POLICY."""
	assert_true(_bridge.designate_zone(_basin(), ZONE_FORAGE, 0, PackedInt32Array([5])),
		"the designation is accepted")
	assert_equal(_commit(), 1, "it commits")
	var zone_slot: int = _designated_zone_slot()
	var enabled_before: bool = _forage.is_zone_enabled(zone_slot)
	assert_true(_bridge.set_zone_enabled(_forage.zone_ref_of(zone_slot), not enabled_before),
		"the toggle is accepted")
	assert_equal(_forage.is_zone_enabled(zone_slot), enabled_before,
		"the flag has not moved while the command is pending")
	assert_true(_dispatch.commit_tick_into(COMMIT_TICK + 1, _report), "the next commit runs")
	assert_equal(_forage.is_zone_enabled(zone_slot), not enabled_before, "and now it has")


func test_naming_a_resident_is_a_command_and_reaches_the_resident_store() -> void:
	"""UI-SET-082's name editor commits through NAME_RESIDENT, never through `set_name()`."""
	var resident: Vector2i = _resident()
	var slot: int = _residents.directory().get_typed_row(resident)
	assert_false(_residents.is_named(slot), "the resident starts anonymous")
	assert_true(_bridge.name_resident(resident, "Rowan"), "the name is accepted")
	assert_false(_residents.is_named(slot), "and is not applied while pending")
	assert_equal(_commit(), 1, "it commits")
	assert_true(_residents.is_named(slot), "the resident is now named")
	assert_equal(_residents.name_key_of(slot), &"Rowan", "with exactly the name typed")


func test_several_paused_edits_queue_in_order_and_change_nothing() -> void:
	"""ARCH-CMD-001: multiple paused commands preserve sequence and leave the stores alone."""
	var basin: Vector2i = _basin()
	var zones_before: int = _forage.zone_count()
	for index: int in 5:
		assert_true(_bridge.designate_zone(basin, ZONE_FORAGE, 0,
			PackedInt32Array([index * 4 + 1, index * 4 + 2])), "edit %d is accepted" % index)
	assert_equal(_queue.pending_count(), 5, "five commands are pending")
	assert_equal(_forage.zone_count(), zones_before, "and no store has changed at all")
	assert_equal(_bridge.submitted_count(), 5, "the interface counted five player actions")


# --- refusals reach the player ----------------------------------------------------------------

func test_an_empty_zone_stroke_is_refused_before_it_reaches_the_queue() -> void:
	"""A stroke with no tiles is the player's mistake, and is named as such."""
	assert_false(_bridge.designate_zone(_basin(), ZONE_FORAGE, 0, PackedInt32Array()),
		"an empty stroke refuses")
	assert_equal(_bridge.last_refusal(), UiCommandBridge.REFUSE_NO_TILES, "with a named code")
	assert_equal(_queue.pending_count(), 0, "and nothing was queued")
	assert_true(_bridge.last_refusal_sentence().contains("tile"),
		"the player is told about tiles: '%s'" % _bridge.last_refusal_sentence())


func test_unsorted_tiles_are_refused_against_the_owning_payload_schema() -> void:
	"""§8.1's zone-tile payload is ascending; an unsorted stroke never becomes a command."""
	assert_false(_bridge.designate_zone(_basin(), ZONE_FORAGE, 0, PackedInt32Array([7, 5, 6])),
		"a descending pair refuses")
	assert_equal(_bridge.last_refusal(), UiCommandBridge.REFUSE_TILES_UNSORTED, "with a named code")
	assert_false(_bridge.designate_zone(_basin(), ZONE_FORAGE, 0, PackedInt32Array([5, 5])),
		"a repeated tile refuses too")
	assert_equal(_queue.pending_count(), 0, "and neither reached the queue")


func test_an_alias_outside_the_save_rule_is_refused() -> void:
	"""ARCH-SAVE-005's 2-32 character alias bound is checked before the command is built."""
	var resident: Vector2i = _resident()
	assert_false(_bridge.name_resident(resident, "R"), "one character refuses")
	assert_equal(_bridge.last_refusal(), UiCommandBridge.REFUSE_ALIAS_LENGTH, "with a named code")
	assert_false(_bridge.name_resident(resident, "R".repeat(33)), "thirty-three refuses")
	assert_true(_bridge.name_resident(resident, "Ro"), "two characters is the minimum and passes")


func test_an_undefined_quota_mode_is_refused_rather_than_sent() -> void:
	"""Decision 0030 defines three quota modes; a fourth is not a value to submit."""
	assert_false(_bridge.set_quota_mode(Vector2i(0, 1), ForageScript.QUOTA_MODE_COUNT),
		"a fourth mode refuses")
	assert_equal(_bridge.last_refusal(), UiCommandBridge.REFUSE_UNKNOWN_POLICY_VALUE,
		"with UNKNOWN_POLICY_VALUE")
	assert_equal(_queue.pending_count(), 0, "and nothing was queued")


func test_an_unbound_interface_refuses_instead_of_pretending_to_act() -> void:
	"""A bridge with no queue must say so; a silent no-op would read as success on screen."""
	var loose: UiCommandBridge = UiCommandBridge.new()
	assert_false(loose.cancel_job(Vector2i(0, 1)), "a cancellation with no queue refuses")
	assert_equal(loose.last_refusal(), UiCommandBridge.REFUSE_NO_QUEUE, "with NO_COMMAND_QUEUE")
	assert_equal(loose.pending_count(), 0, "and it reports no pending work")
	assert_false(loose.bind_queue(null), "binding null refuses as well")
	assert_true(loose.bind_queue(_queue), "and binding a real queue succeeds")


func test_a_queue_refusal_is_carried_through_with_its_own_code() -> void:
	"""The queue's refusal is the player's answer; the bridge neither hides nor rewrites it."""
	assert_false(_bridge.designate_zone(Vector2i(500, 1), ZONE_FORAGE, 0, PackedInt32Array([1])),
		"a target that does not exist refuses")
	assert_true(String(_bridge.last_refusal()).begins_with("COMMAND_"),
		"the code is the queue's own, got '%s'" % _bridge.last_refusal())
	assert_equal(_bridge.refused_count(), 1, "and the refusal is counted")


func test_an_unknown_refusal_code_is_shown_verbatim_rather_than_generically() -> void:
	"""§7 forbids a message that names no cause; an unknown code is more useful than an apology."""
	var sentence: String = _bridge.refusal_sentence(&"SOME_NEW_CODE_FROM_ANOTHER_MODULE")
	assert_equal(sentence, "SOME_NEW_CODE_FROM_ANOTHER_MODULE", "the code survives intact")
	assert_equal(_bridge.refusal_sentence(&""), "", "and no refusal produces no message")
	var known: String = _bridge.refusal_sentence(&"COMMAND_JOB_NOT_CANCELLABLE")
	assert_true(known.contains("COMMAND_JOB_NOT_CANCELLABLE"), "a known code is still quoted")
	assert_true(known.length() > 40, "alongside its plain reading: '%s'" % known)
