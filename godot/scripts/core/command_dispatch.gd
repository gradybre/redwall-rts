extends RefCounted
## ARCH-SYS-002 CommandCommit: the stage that turns an admitted player command into a store write.
##
## `commands.gd` built the ordered next-tick queue and STOPS at the drain -- its header says in
## terms "NO PRODUCER IS CALLED. This is admission and ordering, not dispatch." This module is that
## dispatch. It is the first thing in the project through which a player action reaches the
## simulation: a DESIGNATE_ZONE command committed here designates a real FORAGE zone, binds it to a
## real ecology basin and enables `job_planner.gd`'s repeat-harvest demand, and the very next
## planner tick publishes a real FORAGE Job.
##
## ---------------------------------------------------------------------------------------
## ADMISSION AND COMMIT ARE DIFFERENT VALIDATIONS, AND THAT IS THE POINT. Task 04.2: "Admission
## validates the envelope; commit REVALIDATES current targets and availability." `commands.gd`
## checked the target EntityRef against the directory at SUBMIT time. Between then and the tick
## that executes it, the target can be destroyed, and its slot can be reused by a later entity of
## the same or a different kind. `_resolve_target()` therefore validates again HERE:
##   * a destroyed target refuses COMMAND_TARGET_STALE -- the generation no longer matches;
##   * a slot reused by another KIND refuses COMMAND_TARGET_KIND rather than editing whatever now
##     lives there, which is the failure a generation check alone does not catch;
##   * a kind that needs a target and was given the null reference refuses COMMAND_TARGET_REQUIRED.
## None of these is a clamp and none is a sentinel: every one is an explicit StringName code with a
## stable integer id, published by `result_code()` and `result_code_id()`.
##
## ---------------------------------------------------------------------------------------
## WHOLE COMMANDS SUCCEED OR REFUSE ATOMICALLY (decision 0024, allocate before consume). Every arm
## that writes more than once PREFLIGHTS EVERY WRITE BEFORE THE FIRST ONE:
##   * SET_ACTIVITY_SCHEDULE validates all 24 hour bytes, then writes 24 hours. A day with one
##     illegal hour changes NO hour.
##   * SET_JOB_PRIORITIES validates every (kind, priority) row AND both toggles, then writes. A
##     list with one bad priority leaves every priority and both toggles exactly as they were.
##   * CANCEL_JOB proves the job is cancellable before releasing its worker, so it can never
##     release a worker and then fail to cancel.
##   * DESIGNATE_ZONE is the only arm that cannot preflight to certainty, because it creates the
##     zone it then edits. It preflights the directory capacity, the basin, the zone type, the
##     danger band and every tile, and if a store still refuses it DESTROYS THE ZONE IT CREATED and
##     refuses. `forage.destroy_zone()` releases the tile links and the directory slot, so the
##     rollback is the store's own operation and not a hand-written unwind.
## The one thing a rollback cannot restore is the directory GENERATION the created row consumed.
## That is not policy and not goods; it is recorded here rather than hidden.
##
## ---------------------------------------------------------------------------------------
## WHICH KINDS ARE IMPLEMENTED, AND WHY THE OTHER EIGHTEEN REFUSE. ARCH-CMD-003 fixes 24 kinds.
## Task 04.2 implements them "where their owning stores/contracts exist" and requires the rest to
## reach an "explicit unsupported-feature refusal, never silent success". Six exist:
##
##   CANCEL_JOB             `jobs.gd`      set_state(CANCELLED), after release_worker()
##   DESIGNATE_ZONE         `forage.gd` + `job_planner.gd`   create_zone/set_basin/add_tile,
##                                          then enable_forage_demand()
##   NAME_RESIDENT          `residents.gd` set_name(), under ARCH-SAVE-005's alias rule
##   SET_ACTIVITY_SCHEDULE  `schedule.gd`  set_hour_activity() x24
##   SET_JOB_PRIORITIES     `priorities.gd` set_priority()/set_auto_fallback()/set_dangerous_work()
##   SET_POLICY             `forage.gd`    set_quota_mode(), set_zone_enabled()
##
## ---------------------------------------------------------------------------------------
## THE PER-KIND PAYLOAD SCHEMAS ARE THIS FILE'S, BECAUSE NOWHERE ELSE STATES THEM. §8.1 says only
## that payloads "contain full selection ID lists, schedule bytes, zone tiles, recipe orders, or
## sanitized aliases; the payload schema is selected by the command kind", and `commands.gd`'s
## header records that it therefore left all 24 unspecified for 04.2. These six are decision 0043:
##
##   DESIGNATE_ZONE         target = the ecology BASIN; arg0 = ZoneType; arg1 = §5.5 danger band;
##                          payload = §8.1's "zone tiles": i32 count then that many ascending i32
##                          TILE INDICES, bounded by `forage.is_tile_index()` -- the owning store's
##                          own 128x128 grid predicate, not a number invented here.
##   SET_POLICY             target = the zone; arg0 = policy selector; arg1 = that policy's value.
##                          A single unlabelled integer would make two policies indistinguishable
##                          in a saved command, so the selector is explicit.
##   SET_JOB_PRIORITIES     target = the resident; payload = ARCH-CMD-003's "count first followed
##                          by owner-ID-sorted rows": i32 count then `(job_kind, priority)` i32
##                          pairs in ascending kind order. arg0/arg1 are the auto-fallback and
##                          dangerous-work toggles as -1 unchanged / 0 off / 1 on, so a priority
##                          edit is not forced to restate an unrelated consent.
##   SET_ACTIVITY_SCHEDULE  target = the resident; payload = §8.1's "schedule bytes": exactly 24
##                          Activity bytes, one per hour. The whole day is the schema because it
##                          is the only shape §8.1 names AND because it is atomic by construction.
##   NAME_RESIDENT          target = the resident; payload = §8.1's "sanitized alias" as UTF-8
##                          bytes, under ARCH-SAVE-005's 2-32 character, no-control-character rule.
##   CANCEL_JOB             target = the Job. No payload and no argument: the identity IS the whole
##                          command, so a nonempty payload is refused rather than ignored.
##
## The other eighteen refuse COMMAND_UNSUPPORTED_FEATURE and name their missing owner in
## `unsupported_reason()`. SET_MANUAL_TASK and CANCEL_MANUAL are among them: THERE IS NO ManualTask
## STORE, because blocker U6 records that "owner-major indexing for the 8-per-resident store is
## unspecified" -- `jobs.gd` and `schedule.gd` both say so in their own headers, and `manual_until`
## is a reserved always-zero column. Inventing the index formula here would be inventing the
## contract U6 exists to protect. EQUIP is refused for a different reason and says so: `gear.gd`
## exists, but who may equip what and when is task 06's contract, not this module's to author.
##
## ---------------------------------------------------------------------------------------
## NOTHING HERE WRITES `JOB_STATE_WORK`, EVER. Task 04.2: "Do not advance a RESERVED job to WORK to
## make a command appear successful." Movement does not exist -- there is no Transform store, no
## pathfinder and no arrival callback -- so RESERVED -> TRAVEL -> WORK has no owner. A command that
## produces a job produces a QUEUED job and leaves it QUEUED. That is the correct visible outcome,
## and `test_command_dispatch.gd` asserts the state by value rather than trusting this paragraph.
##
## ---------------------------------------------------------------------------------------
## ONE SOURCE INTENT PRODUCES AT MOST ONE DESIGNATION (task 04.4: "Record source intent/job
## identity so repeated evaluation cannot duplicate a job"). `job_planner.gd` already makes
## REPEATED EVALUATION idempotent -- `(designation EntityRef, patch kind)` is its demand identity
## and a repeat `enable_forage_demand()` refuses -- but that is the PRODUCER's guard, and it is
## per designation. It cannot see that TWO designations came from ONE player command.
##
## THEY CAN, AND IT WAS MEASURED BEFORE IT WAS FIXED. `commands.gd` refuses a duplicate
## `(execute_tick, player_id, sequence)` key only while the record is still QUEUED, and refuses a
## replayed `execute_tick` that has already completed. Neither catches the same envelope
## re-admitted through `admit_stamped_into()` at a LATER tick: on 2026-09-10 that committed a
## SECOND designation over the same basin and left `forage.zone_count()` at 9 and
## `job_planner.forage_demand_enabled_count()` at 2 for ONE player intent. No second Job appeared
## in that run only because the first harvest's claim still held the shared quota, which is the
## accounting saving the identity rather than the identity holding.
##
## SO THE INTENT IS RECORDED ON WHAT IT PRODUCED. `_intent_*` is one row per HarvestZone row
## carrying ARCH-CMD-001's own `(player_id, sequence_high, sequence_low)` plus the produced zone's
## GENERATION. `_live_zone_of_intent()` is checked in DESIGNATE_ZONE's preflight, before anything
## is created, and a repeat refuses COMMAND_DUPLICATE_INTENT. Three things this deliberately does
## NOT do:
##   * IT DOES NOT DEDUPLICATE BY CONTENT. Two commands with different sequences over the same
##     basin and the same tiles are two genuine intents: `forage.gd` states that "§5.1's
##     overlapping designations are the case the per-tile list exists for", so refusing them would
##     contradict the owning store.
##   * IT IS NOT A WINDOW OVER HISTORY. The ledger is indexed BY the zone row it describes, so it
##     is bounded by `forage.gd`'s own 128 designations and can never forget an intent whose
##     designation is still alive. An intent whose designation was destroyed is no longer a
##     duplicate, because there is no second job for it to duplicate.
##   * IT DOES NOT PERSIST. There is no save module; task 09 owns the codec. Across a process the
##     guard is untested and unclaimed, exactly as the result ledger is.
##
## ---------------------------------------------------------------------------------------
## PENDING AND RESULT PROJECTIONS ARE COPIES, NOT HANDLES. Task 04.2: "immutable presentation
## projections show pending entries and cancellation state. No UI callback edits resident, ecology,
## jobs or inventory stores directly." `pending_into()` and `result_into()` fill a record the
## CALLER owns; this module hands out no reference to a column, no reference to a store and no
## mutable view of the queue. A UI that wants to change something submits a command.
##
## RESULT IDS ARE DETERMINISTIC AND DOCUMENTED. `RESULT_CODES` is an ASCII-sorted array whose INDEX
## is the id, proven sorted and unique by `_assert_contracts()`, exactly as `catalog.gd` proves its
## compiled domains. The id is what the result ledger stores and what a save or a replay would
## carry; the StringName is what a player-facing string table keys off. A store's OWN refusal code
## is retained verbatim alongside it in `_result_store_code`, so "COMMAND_STORE_REFUSED" is never
## the whole story a player is given.
##
## ---------------------------------------------------------------------------------------
## WHAT THIS DELIBERATELY DOES NOT DO:
##
##   * ARCH-CMD-002's SPEED/PAUSE SCHEDULER EVENTS ARE NOT HERE, and now that they EXIST that is a
##     stronger statement than it used to be. `scripts/core/scheduler_events.gd` implements
##     R07-SCHED-001 (decision 0054) as a SEPARATE queue that applies its events at the boundary
##     pump between ticks. They must never be routed through this dispatcher: an economic command
##     commits at `completed_tick + 1`, so a pause committed here would wait for the tick it
##     exists to prevent. `sim_clock.gd`'s U2 header records what closed and what did not.
##   * NO SAVE. There is no save module in this repository, so the result ledger and the pending
##     queue are in-process only. Task 09 owns the codec; 04.1 owns the pending-command subsection.
##   * `goal_x`/`goal_z` ARE NOT READ BY ANY ARM. Decision 0042 records that §8.1 types them i32 and
##     names no unit, so no map bound can be sourced for them. The one spatial payload here is a
##     TILE INDEX list, which `forage.gd` does define and does bound (`is_tile_index()`), so it is
##     validated against that store rather than against a number invented here.
##   * NO JOB IS RESERVED, ROUTED OR COMPLETED. This stage commits intent; ARCH-SYS-009 publishes
##     the work and ARCH-SYS-010 selects it, both on their own stages and both after this one.
##
## ALLOCATION ON THE TICK PATH, named rather than claimed away. Per committed command this module
## allocates nothing of its own: every column, the payload scratch and the reused records are sized
## once in `_init()`. It calls store functions that allocate INSIDE modules it does not own -- each
## returns one `OpResult` or `IntResult` per call, their published contract. The ONE allocation of
## its own is in `_commit_name_resident()`: decoding an alias slices the payload and builds a
## String. That is per RENAME, an occasional player action, and it is named here rather than denied.

const Catalog := preload("res://scripts/core/catalog.gd")
const CommandsScript := preload("res://scripts/core/commands.gd")
const EntityDirectory := preload("res://scripts/core/entity_directory.gd")
const ForageScript := preload("res://scripts/core/forage.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const JobPlannerScript := preload("res://scripts/core/job_planner.gd")
const JobsScript := preload("res://scripts/core/jobs.gd")
const PrioritiesScript := preload("res://scripts/core/priorities.gd")
const ResidentsScript := preload("res://scripts/core/residents.gd")
const ScheduleScript := preload("res://scripts/core/schedule.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")

# --- ARCH-CMD-003's 24 kind ids, read from the compiled catalog and never respelled -------------

const KIND_ACCEPT_CANDIDATES: int = Catalog.COMMAND_KIND["ACCEPT_CANDIDATES"]
const KIND_CANCEL_JOB: int = Catalog.COMMAND_KIND["CANCEL_JOB"]
const KIND_CANCEL_MANUAL: int = Catalog.COMMAND_KIND["CANCEL_MANUAL"]
const KIND_DESIGNATE_ZONE: int = Catalog.COMMAND_KIND["DESIGNATE_ZONE"]
const KIND_NAME_RESIDENT: int = Catalog.COMMAND_KIND["NAME_RESIDENT"]
const KIND_SET_ACTIVITY_SCHEDULE: int = Catalog.COMMAND_KIND["SET_ACTIVITY_SCHEDULE"]
const KIND_SET_JOB_PRIORITIES: int = Catalog.COMMAND_KIND["SET_JOB_PRIORITIES"]
const KIND_SET_MANUAL_TASK: int = Catalog.COMMAND_KIND["SET_MANUAL_TASK"]
const KIND_SET_POLICY: int = Catalog.COMMAND_KIND["SET_POLICY"]
const KIND_COUNT: int = 24

## Why each unimplemented kind refuses, indexed by kind id. The empty name marks an implemented
## kind. These are the missing OWNERS, named: a reader must be able to see which store is absent
## rather than being told only that something is unsupported.
const UNSUPPORTED_REASON: Array[StringName] = [
	&"NO_IMMIGRATION_CANDIDATE_STORE",
	&"NO_WARDEN_APPOINTMENT_CONTRACT",
	&"NO_FURNITURE_OR_BED_STORE",
	&"",
	&"NO_MANUAL_TASK_STORE_BLOCKER_U6",
	&"NO_FEAST_STORE",
	&"NO_BUILDING_STORE",
	&"NO_ROOM_STORE",
	&"",
	&"NO_PRODUCTION_ORDER_STORE",
	&"EQUIP_CONTRACT_OWNED_BY_TASK_06",
	&"",
	&"NO_CONSTRUCTION_STORE",
	&"NO_FURNITURE_STORE",
	&"NO_RELIEF_SEED_POLICY",
	&"",
	&"NO_DOOR_STORE",
	&"NO_FIELD_POLICY_STORE",
	&"",
	&"NO_MANUAL_TASK_STORE_BLOCKER_U6",
	&"",
	&"NO_BUILDING_ITEM_FILTER_STORE",
	&"NO_BUILDING_ITEM_MINIMUM_STORE",
	&"NO_BUILDING_STORE",
]

# --- the deterministic result domain: index IS the id ------------------------------------------

## ASCII-sorted and unique, proven by `_assert_contracts()`. The index is the stable id a ledger
## row, a save or a replay carries; renaming one without re-sorting would renumber the rest, which
## is why the sort is an assertion and not a comment.
const RESULT_CODES: Array[StringName] = [
	&"COMMAND_ALIAS_CONTROL_CHARACTER",
	&"COMMAND_ALIAS_LENGTH",
	&"COMMAND_ALIAS_MALFORMED_UTF8",
	&"COMMAND_ARGUMENT_RANGE",
	&"COMMAND_BASIN_CHAIN",
	&"COMMAND_BASIN_TYPE",
	&"COMMAND_COMMITTED",
	&"COMMAND_DUPLICATE_INTENT",
	&"COMMAND_JOB_NOT_CANCELLABLE",
	&"COMMAND_PAYLOAD_SCHEMA",
	&"COMMAND_PAYLOAD_UNREADABLE",
	&"COMMAND_POLICY_NOT_VALID_HERE",
	&"COMMAND_STORE_NOT_BOUND",
	&"COMMAND_STORE_REFUSED",
	&"COMMAND_TARGET_KIND",
	&"COMMAND_TARGET_REQUIRED",
	&"COMMAND_TARGET_STALE",
	&"COMMAND_UNSUPPORTED_FEATURE",
	&"COMMAND_ZONE_CAPACITY",
	&"COMMAND_ZONE_LINK_CAPACITY",
	&"COMMAND_ZONE_TILE_RANGE",
	&"COMMAND_ZONE_TILE_UNSORTED",
]

const RESULT_ALIAS_CONTROL_CHARACTER: int = 0
const RESULT_ALIAS_LENGTH: int = 1
const RESULT_ALIAS_MALFORMED_UTF8: int = 2
const RESULT_ARGUMENT_RANGE: int = 3
const RESULT_BASIN_CHAIN: int = 4
const RESULT_BASIN_TYPE: int = 5
const RESULT_COMMITTED: int = 6
const RESULT_DUPLICATE_INTENT: int = 7
const RESULT_JOB_NOT_CANCELLABLE: int = 8
const RESULT_PAYLOAD_SCHEMA: int = 9
const RESULT_PAYLOAD_UNREADABLE: int = 10
const RESULT_POLICY_NOT_VALID_HERE: int = 11
const RESULT_STORE_NOT_BOUND: int = 12
const RESULT_STORE_REFUSED: int = 13
const RESULT_TARGET_KIND: int = 14
const RESULT_TARGET_REQUIRED: int = 15
const RESULT_TARGET_STALE: int = 16
const RESULT_UNSUPPORTED_FEATURE: int = 17
const RESULT_ZONE_CAPACITY: int = 18
const RESULT_ZONE_LINK_CAPACITY: int = 19
const RESULT_ZONE_TILE_RANGE: int = 20
const RESULT_ZONE_TILE_UNSORTED: int = 21
const RESULT_COUNT: int = 22

# --- this module's own refusals (stage level, not per command) ----------------------------------

const REFUSE_NONE: StringName = &""
const REFUSE_INVALID_TICK: StringName = &"INVALID_TICK"
const REFUSE_NO_QUEUE: StringName = &"NO_COMMAND_QUEUE"
const REFUSE_SHARED_DIRECTORY: StringName = &"STORES_DO_NOT_SHARE_A_DIRECTORY"
const REFUSE_INVALID_RESULT_ID: StringName = &"INVALID_RESULT_ID"
const REFUSE_NO_SOURCE_INTENT: StringName = &"NO_SOURCE_INTENT"

# --- payload schemas, each derived from its owning store's own published bound ------------------

## SET_ACTIVITY_SCHEDULE carries §8.1's "schedule bytes": one Activity per hour, 24 of them.
const SCHEDULE_PAYLOAD_BYTES: int = ScheduleScript.HOURS_PER_DAY
const ACTIVITY_COUNT: int = ScheduleScript.ACTIVITY_COUNT

## SET_JOB_PRIORITIES carries ARCH-CMD-003's "count first followed by owner-ID-sorted rows": an
## i32 row count, then that many `(job_kind:i32, priority:i32)` rows in ascending kind order.
const GROUP_COUNT_BYTES: int = 4
const PRIORITY_ROW_BYTES: int = 8
const JOB_KIND_COUNT: int = PrioritiesScript.JOB_KIND_COUNT

## The two SET_JOB_PRIORITIES toggles ride in the envelope's own i32 argument fields. -1 leaves the
## stored value untouched, so a priority edit is not forced to restate an unrelated consent.
const TOGGLE_UNCHANGED: int = -1
const TOGGLE_OFF: int = 0
const TOGGLE_ON: int = 1

## SET_POLICY names WHICH policy it edits in `arg0` and its value in `arg1`, because §8.1 fixes
## no per-kind schema and a single unlabelled integer would make two policies indistinguishable in
## a saved command. Both selectors edit `forage.gd`; every other settlement policy named by the GDD
## belongs to a store that does not exist yet, and its selector is added when that store is.
const POLICY_FORAGE_QUOTA_MODE: int = 0
const POLICY_FORAGE_ZONE_ENABLED: int = 1
const POLICY_COUNT: int = 2

## DESIGNATE_ZONE carries §8.1's "zone tiles": an i32 tile count, then that many i32 tile indices
## in ascending order with no repeat. The ceiling is `forage.gd`'s own total link budget.
const TILE_ROW_BYTES: int = 4
const ZONE_TILE_MAX_ROWS: int = ForageScript.ZONE_LINK_CAPACITY

## ARCH-SAVE-005: "Player aliases are 2-32 Unicode characters with control characters rejected".
## The byte ceiling is 32 characters at UTF-8's 4-byte maximum; a longer payload is refused before
## it is decoded rather than truncated.
const ALIAS_MIN_CHARACTERS: int = 2
const ALIAS_MAX_CHARACTERS: int = 32
const ALIAS_MAX_BYTES: int = ALIAS_MAX_CHARACTERS * 4
const ASCII_SPACE: int = 32
const ASCII_DELETE: int = 127

## Every kind's payload fits this one buffer, so no arm resizes anything per tick.
const PAYLOAD_SCRATCH_BYTES: int = GROUP_COUNT_BYTES + TILE_ROW_BYTES * ZONE_TILE_MAX_ROWS

## One result row per queued command, so a tick that drains a full queue loses no result.
const RESULT_CAPACITY: int = CommandsScript.QUEUE_CAPACITY

## Task 04.4's SOURCE INTENT LEDGER: one row per HarvestZone row, because the only entity a
## player command can CREATE today is a designation and `forage.gd` holds exactly this many.
## The ledger is bounded by the thing it describes rather than by a window over history, which
## is why it can never silently forget an intent whose designation is still alive.
const INTENT_CAPACITY: int = ForageScript.HARVEST_ZONE_CAPACITY

## No command produced this zone row. A world-generated basin carries this forever.
const NO_INTENT_PLAYER: int = -1


class TickReport:
	"""Outcome of one CommandCommit stage, caller-owned and reused.

	`.ok` MUST be inspected first. `drained` counts what the queue handed over, `committed` and
	`refused` split it; the two always sum to `drained` on a successful stage.
	"""
	var ok: bool = false
	var error: StringName = &""
	var drained: int = 0
	var committed: int = 0
	var refused: int = 0

	func fill(p_ok: bool, p_error: StringName, p_drained: int, p_committed: int,
			p_refused: int) -> void:
		"""Overwrite this report in place, so a stage allocates nothing."""
		ok = p_ok
		error = p_error
		drained = p_drained
		committed = p_committed
		refused = p_refused


class ResultRow:
	"""One committed or refused command's outcome: an immutable projection the caller owns.

	`code_id` indexes `RESULT_CODES`. `store_code` is the ORIGINATING store's own refusal
	StringName when a store refused, and the empty name otherwise, so a player-facing message can
	say which store said no rather than only that one did.
	"""
	var execute_tick: int = 0
	var sequence_low: int = 0
	var sequence_high: int = 0
	var kind: int = 0
	var code_id: int = 0
	var value: int = 0
	var target_slot: int = -1
	var target_generation: int = 0
	var store_code: StringName = &""

	func ok() -> bool:
		"""True when this command committed."""
		return code_id == RESULT_COMMITTED

	func code() -> StringName:
		"""This outcome's deterministic StringName, from the documented sorted domain."""
		return RESULT_CODES[code_id]


class PendingRow:
	"""One queued, unexecuted command as presentation sees it: a copy, never a handle.

	`is_cancellation` is what a pending list needs in order to draw a cancellation differently
	from an edit, and `is_supported` is what it needs in order to warn BEFORE the tick that a
	kind will refuse. Neither can change anything: this record is the caller's own.
	"""
	var execute_tick: int = 0
	var sequence_low: int = 0
	var sequence_high: int = 0
	var kind: int = 0
	var target_slot: int = -1
	var target_generation: int = 0
	var arg0: int = 0
	var arg1: int = 0
	var payload_length: int = 0
	var is_cancellation: bool = false
	var is_supported: bool = false


class IntentRow:
	"""The player command that produced one designation, as presentation sees it: a copy.

	ARCH-CMD-001's `(player_id, sequence_high, sequence_low)` is the identity of one player
	command, and `zone_slot`/`zone_generation` are the designation it created. A UI uses this to
	say WHICH order made a zone; it cannot edit anything, because it is the caller's own record.
	"""
	var zone_slot: int = -1
	var zone_generation: int = 0
	var player_id: int = 0
	var sequence_high: int = 0
	var sequence_low: int = 0


# --- collaborating stores. A null store is UNBOUND, and its kinds refuse rather than no-op ------

var _queue: CommandsScript = null
var _directory: EntityDirectory = null
var _residents: ResidentsScript = null
var _priorities: PrioritiesScript = null
var _schedule: ScheduleScript = null
var _jobs: JobsScript = null
var _forage: ForageScript = null
var _planner: JobPlannerScript = null

# --- the result ledger: packed columns, allocated once (ARCH-MEM-001) ---------------------------

var _result_execute_tick: PackedInt64Array = PackedInt64Array()
var _result_sequence_low: PackedInt32Array = PackedInt32Array()
var _result_sequence_high: PackedInt32Array = PackedInt32Array()
var _result_kind: PackedInt32Array = PackedInt32Array()
var _result_code: PackedInt32Array = PackedInt32Array()
var _result_value: PackedInt32Array = PackedInt32Array()
var _result_target_slot: PackedInt32Array = PackedInt32Array()
var _result_target_generation: PackedInt32Array = PackedInt32Array()
## The originating store's own code, held as an interned StringName. Assigning one is a reference
## copy, not an allocation, which is why a String column is not used here.
var _result_store_code: Array[StringName] = []

# --- the source-intent ledger: one player command identity per created zone row -----------------

## Task 04.4: "Record source intent/job identity so repeated evaluation cannot duplicate a job."
## `(player_id, sequence_high, sequence_low)` is ARCH-CMD-001's own identity for one player
## command, and `_intent_zone_generation` is the generation of the designation that command
## produced -- both halves, so a zone row the directory has since handed to another entity cannot
## be mistaken for the same designation.
var _intent_player_id: PackedInt32Array = PackedInt32Array()
var _intent_sequence_high: PackedInt32Array = PackedInt32Array()
var _intent_sequence_low: PackedInt32Array = PackedInt32Array()
var _intent_zone_generation: PackedInt32Array = PackedInt32Array()
var _duplicate_intent_count: int = 0

var _result_write: int = 0
var _result_count: int = 0
var _results_recorded: int = 0
var _committed_count: int = 0
var _refused_count: int = 0

# --- scratch (not simulation state) -------------------------------------------------------------

var _drained: CommandsScript.Command = CommandsScript.Command.new()
var _payload: PackedByteArray = PackedByteArray()
var _calendar: SimClock.Calendar = SimClock.Calendar.new(0)
var _math: IntMath.IntResult = IntMath.IntResult.new()
## Resolved by `_resolve_target()` and consumed by the arm that called it, with no callback in
## between. A plain int, written and read inside one dispatch.
var _target_row: int = EntityDirectory.NULL_SLOT
## The last store refusal seen while dispatching, recorded into the ledger row being written.
var _store_code: StringName = REFUSE_NONE
var _last_refusal: StringName = REFUSE_NONE


func _init(p_queue: CommandsScript, p_residents: ResidentsScript = null,
		p_priorities: PrioritiesScript = null, p_schedule: ScheduleScript = null,
		p_jobs: JobsScript = null, p_forage: ForageScript = null,
		p_planner: JobPlannerScript = null) -> void:
	"""Bind the queue and whichever stores this composition owns, and size the ledger once.

	Every bound store must share the queue's ONE `EntityDirectory`, because a target validated at
	admission against one directory and committed against another would be validated against the
	wrong generations. A mismatch asserts here rather than being discovered by a wrong write.
	"""
	assert(p_queue != null, "the command dispatcher requires the ordered command queue")
	_queue = p_queue
	_directory = p_queue.directory()
	_residents = p_residents
	_priorities = p_priorities
	_schedule = p_schedule
	_jobs = p_jobs
	_forage = p_forage
	_planner = p_planner
	_assert_contracts()
	_allocate_columns()
	clear()


func _assert_contracts() -> void:
	"""Prove the result domain's sort, the kind domain's size and the one shared directory."""
	assert(RESULT_CODES.size() == RESULT_COUNT, "every result id must name one code")
	for index: int in RESULT_COUNT - 1:
		assert(String(RESULT_CODES[index]) < String(RESULT_CODES[index + 1]),
			"result codes must be ASCII-sorted, because the index is the stored id")
	assert(UNSUPPORTED_REASON.size() == KIND_COUNT,
		"every ARCH-CMD-003 kind must state why it is unsupported, or state that it is not")
	assert(Catalog.COMMAND_KIND.size() == KIND_COUNT, "ARCH-CMD-003 fixes 24 command kinds")
	assert(RESULT_CODES[RESULT_COMMITTED] == &"COMMAND_COMMITTED",
		"the success id must index the success code")
	_assert_shared_directory()


func _assert_shared_directory() -> void:
	"""Prove every bound store validates references against the queue's own directory."""
	assert(_residents == null or _residents.directory() == _directory,
		"the residents store must share the command queue's directory")
	assert(_jobs == null or _jobs.directory() == _directory,
		"the jobs store must share the command queue's directory")
	assert(_forage == null or _forage.directory() == _directory,
		"the forage store must share the command queue's directory")


func _allocate_columns() -> void:
	"""Size every ledger column and the payload scratch exactly once, per ARCH-MEM-001."""
	_result_execute_tick.resize(RESULT_CAPACITY)
	for column: PackedInt32Array in [_result_sequence_low, _result_sequence_high, _result_kind,
			_result_code, _result_value, _result_target_slot, _result_target_generation]:
		column.resize(RESULT_CAPACITY)
	_result_store_code.resize(RESULT_CAPACITY)
	for column: PackedInt32Array in [_intent_player_id, _intent_sequence_high,
			_intent_sequence_low, _intent_zone_generation]:
		column.resize(INTENT_CAPACITY)
	_payload.resize(PAYLOAD_SCRATCH_BYTES)


func clear() -> void:
	"""Empty the result ledger and every counter without reallocating a column."""
	_result_execute_tick.fill(0)
	for column: PackedInt32Array in [_result_sequence_low, _result_sequence_high, _result_kind,
			_result_code, _result_value]:
		column.fill(0)
	_result_target_slot.fill(EntityDirectory.NULL_SLOT)
	_result_target_generation.fill(EntityDirectory.NULL_GENERATION)
	_result_store_code.fill(REFUSE_NONE)
	_intent_player_id.fill(NO_INTENT_PLAYER)
	for column: PackedInt32Array in [_intent_sequence_high, _intent_sequence_low,
			_intent_zone_generation]:
		column.fill(0)
	_duplicate_intent_count = 0
	_payload.fill(0)
	_result_write = 0
	_result_count = 0
	_results_recorded = 0
	_committed_count = 0
	_refused_count = 0
	_store_code = REFUSE_NONE
	_last_refusal = REFUSE_NONE


func bind_ecology(p_forage: ForageScript, p_planner: JobPlannerScript) -> bool:
	"""Task 03's named runtime handoff: attach the ecology store and the planner after composition.

	`settlement_system.gd` composes the resident-side stores; ARCH-SYS-005/009's stores are task
	03's to compose, and this is where they arrive so that DESIGNATE_ZONE and SET_POLICY stop
	refusing COMMAND_STORE_NOT_BOUND. Refuses a store that validates against another directory
	rather than binding one that would resolve a target to the wrong row.
	"""
	if p_forage != null and p_forage.directory() != _directory:
		_last_refusal = REFUSE_SHARED_DIRECTORY
		return false
	_forage = p_forage
	_planner = p_planner
	_last_refusal = REFUSE_NONE
	return true


# --- ARCH-SYS-002: the stage ---------------------------------------------------------------------

func commit_tick_into(executing_tick: int, out: TickReport) -> bool:
	"""Drain and commit every command due at `executing_tick`. The CommandCommit stage itself.

	Runs every tick, "after snapshot, before selectors" (§5). Each drained command is dispatched
	and its outcome recorded, so a refusal is visible rather than silent, and a refusal never
	stops the stage: the next player's next command is not the failed one's hostage.
	"""
	if executing_tick < 0:
		out.fill(false, REFUSE_INVALID_TICK, 0, 0, 0)
		_last_refusal = REFUSE_INVALID_TICK
		return false
	_calendar.set_tick(executing_tick)
	var drained: int = 0
	var committed: int = 0
	while _queue.drain_due_into(executing_tick, _drained):
		drained += 1
		var code: int = _dispatch(_drained)
		_record(_drained, code)
		if code == RESULT_COMMITTED:
			committed += 1
	_last_refusal = REFUSE_NONE
	out.fill(true, REFUSE_NONE, drained, committed, drained - committed)
	return true


func _dispatch(command: CommandsScript.Command) -> int:
	"""Route one drained command to its arm. Returns the deterministic result id.

	Every kind reaches exactly one outcome: a store write, or an explicit refusal id. There is no
	fall-through that reports success, which is the whole reason this function has a default.
	`_math` is cleared first so a refusing arm cannot leave the PREVIOUS command's value in the
	ledger row that is about to be written for this one.
	"""
	_store_code = REFUSE_NONE
	_math.refuse(String(REFUSE_INVALID_RESULT_ID))
	if command.kind == KIND_CANCEL_JOB:
		return _commit_cancel_job(command)
	if command.kind == KIND_DESIGNATE_ZONE:
		return _commit_designate_zone(command)
	if command.kind == KIND_NAME_RESIDENT:
		return _commit_name_resident(command)
	if command.kind == KIND_SET_ACTIVITY_SCHEDULE:
		return _commit_set_activity_schedule(command)
	if command.kind == KIND_SET_JOB_PRIORITIES:
		return _commit_set_job_priorities(command)
	if command.kind == KIND_SET_POLICY:
		return _commit_set_policy(command)
	return RESULT_UNSUPPORTED_FEATURE


func _record(command: CommandsScript.Command, code: int) -> void:
	"""Append one outcome to the ring, overwriting the oldest row once it is full."""
	var row: int = _result_write
	_result_execute_tick[row] = command.execute_tick
	_result_sequence_low[row] = command.sequence_low
	_result_sequence_high[row] = command.sequence_high
	_result_kind[row] = command.kind
	_result_code[row] = code
	_result_value[row] = _math.value if _math.ok else 0
	_result_target_slot[row] = command.target_slot
	_result_target_generation[row] = command.target_generation
	_result_store_code[row] = _store_code
	_result_write = (_result_write + 1) % RESULT_CAPACITY
	if _result_count < RESULT_CAPACITY:
		_result_count += 1
	_results_recorded += 1
	if code == RESULT_COMMITTED:
		_committed_count += 1
	else:
		_refused_count += 1


# --- commit-time revalidation -------------------------------------------------------------------

func _resolve_target(command: CommandsScript.Command, expected_kind: int) -> int:
	"""Revalidate one command's target NOW, not as it was at admission. RESULT_COMMITTED when clean.

	The resolved typed row is left in `_target_row` for the arm that called this. A destroyed
	target refuses stale; a slot whose generation was reused by another kind refuses kind, which
	is the case a generation check alone cannot see when the directory hands the row back out.
	"""
	_target_row = EntityDirectory.NULL_SLOT
	if command.target_slot == EntityDirectory.NULL_SLOT:
		return RESULT_TARGET_REQUIRED
	var ref: Vector2i = Vector2i(command.target_slot, command.target_generation)
	if not _directory.is_valid(ref):
		return RESULT_TARGET_STALE
	if _directory.get_kind(ref) != expected_kind:
		return RESULT_TARGET_KIND
	_target_row = _directory.get_typed_row(ref)
	return RESULT_COMMITTED


func _load_payload(command: CommandsScript.Command, expected_bytes: int) -> int:
	"""Copy one command's payload into the shared scratch, refusing a length this kind cannot use.

	`expected_bytes` is the exact length this kind's schema requires. The length is checked BEFORE
	the copy, so a command claiming a megabyte never touches the scratch buffer.
	"""
	if command.payload_length != expected_bytes:
		return RESULT_PAYLOAD_SCHEMA
	if expected_bytes == 0:
		return RESULT_COMMITTED
	if not _queue.read_payload_into(command, _payload):
		return RESULT_PAYLOAD_UNREADABLE
	return RESULT_COMMITTED


func _group_row_count(command: CommandsScript.Command, row_bytes: int, max_rows: int) -> int:
	"""Validate a count-prefixed payload's SHAPE and load it. RESULT_COMMITTED when it is loadable.

	ARCH-CMD-003's "count first followed by owner-ID-sorted rows". The declared count must agree
	with the payload length exactly -- a shorter or longer buffer is refused, never trusted and
	never padded. The row count is left in `_math` for the caller.

	THE EXACT-LENGTH IDENTITY IS THE ONLY CHECK THAT DECIDES A VERDICT, and the two guards around
	it are here for a stated reason rather than as redundancy. The LOWER one refuses a payload too
	short to hold a count at all, so `decode_s32(0)` is never asked to read a count out of bytes
	this command did not supply -- the scratch is shared, and those bytes would be the PREVIOUS
	command's. The UPPER one refuses a payload longer than this kind's largest legal group BEFORE
	the copy, so a caller cannot make a tick copy a megabyte only to be told the count is wrong.

	NO SEPARATE `rows` BOUND IS ASSERTED, and its absence is deliberate. Once the identity
	`GROUP_COUNT_BYTES + rows * row_bytes == payload_length` holds and the upper guard has held,
	`rows * row_bytes <= row_bytes * max_rows`, so `rows <= max_rows`; and `payload_length >=
	GROUP_COUNT_BYTES` forces `rows >= 0`. A `rows < 0 or rows > max_rows` clause was written here
	first and REMOVED after mutation testing proved it could not change any verdict: it survived
	being deleted, which is the definition of a line no test can justify.
	"""
	_math.refuse(String(RESULT_CODES[RESULT_PAYLOAD_SCHEMA]))
	if command.payload_length < GROUP_COUNT_BYTES:
		return RESULT_PAYLOAD_SCHEMA
	if command.payload_length > GROUP_COUNT_BYTES + row_bytes * max_rows:
		return RESULT_PAYLOAD_SCHEMA
	var loaded: int = _load_payload(command, command.payload_length)
	if loaded != RESULT_COMMITTED:
		return loaded
	var rows: int = _payload.decode_s32(0)
	if GROUP_COUNT_BYTES + rows * row_bytes != command.payload_length:
		return RESULT_PAYLOAD_SCHEMA
	_math.succeed(rows)
	return RESULT_COMMITTED


# --- CANCEL_JOB ---------------------------------------------------------------------------------

func _commit_cancel_job(command: CommandsScript.Command) -> int:
	"""Cancel one queued or reserved Job, releasing its worker first if it holds one.

	Decision 0017 gives worker departure and job cancellation separate paths, so this calls both
	in that order rather than destroying the row: `destroy_job()` refuses while a worker holds it,
	and a destroy would also discard shared progress the decision requires to survive.
	"""
	if _jobs == null:
		return RESULT_STORE_NOT_BOUND
	var resolved: int = _resolve_target(command, EntityDirectory.KIND_JOB)
	if resolved != RESULT_COMMITTED:
		return resolved
	var empty: int = _load_payload(command, 0)
	if empty != RESULT_COMMITTED:
		return empty
	var job_slot: int = _target_row
	var refusal: int = _cancellable_refusal(job_slot)
	if refusal != RESULT_COMMITTED:
		return refusal
	if not _release_any_worker(job_slot):
		return RESULT_STORE_REFUSED
	var cancelled: JobsScript.OpResult = _jobs.set_state(job_slot,
		JobsScript.JOB_STATE_CANCELLED)
	if not cancelled.ok:
		_store_code = cancelled.error
		return RESULT_STORE_REFUSED
	_math.succeed(job_slot)
	return RESULT_COMMITTED


func _cancellable_refusal(job_slot: int) -> int:
	"""RESULT_COMMITTED when this Job may be cancelled by a player command.

	A finished or already-cancelled job is refused rather than rewritten, and a party job is
	refused because decision 0017 settles worker departure and progress survival but NOT what
	cancelling a coordinator does to its members. Refusing names the gap; guessing would hide it.
	"""
	var state: IntMath.IntResult = _jobs.state_of(job_slot)
	if not state.ok:
		_store_code = StringName(state.error)
		return RESULT_STORE_REFUSED
	if state.value == JobsScript.JOB_STATE_CANCELLED:
		return RESULT_JOB_NOT_CANCELLABLE
	if state.value == JobsScript.JOB_STATE_COMPLETE:
		return RESULT_JOB_NOT_CANCELLABLE
	if _jobs.is_coordinator(job_slot) or _jobs.is_member(job_slot):
		return RESULT_JOB_NOT_CANCELLABLE
	return RESULT_COMMITTED


func _release_any_worker(job_slot: int) -> bool:
	"""Release the worker holding this Job, if one does. True when the job now has none."""
	var worker: Vector2i = _jobs.worker_of(job_slot)
	if worker == EntityDirectory.NULL_REF:
		return true
	var released: JobsScript.OpResult = _jobs.release_worker(_directory.get_typed_row(worker))
	if released.ok:
		return true
	_store_code = released.error
	return false


# --- SET_POLICY --------------------------------------------------------------------------------

func _commit_set_policy(command: CommandsScript.Command) -> int:
	"""Edit one harvest zone's policy: `arg0` selects which policy, `arg1` carries its value.

	The season is NOT carried by the command. A paused edit is due at `completed_tick+1`, so the
	season it takes effect in is the season of the tick that commits it, read from the clock
	rather than from a value the submitter could have staled while the game sat paused.
	"""
	if _forage == null:
		return RESULT_STORE_NOT_BOUND
	var resolved: int = _resolve_target(command, EntityDirectory.KIND_HARVEST_ZONE)
	if resolved != RESULT_COMMITTED:
		return resolved
	if command.arg0 == POLICY_FORAGE_QUOTA_MODE:
		return _commit_quota_mode(command.arg1, _target_row)
	if command.arg0 == POLICY_FORAGE_ZONE_ENABLED:
		return _commit_zone_enabled(command.arg1, _target_row)
	return RESULT_ARGUMENT_RANGE


func _commit_quota_mode(mode: int, zone_slot: int) -> int:
	"""Apply decision 0030 §4.6's quota mode to one zone, preflighting its valid-use column.

	Automatic is a BASIN mode and Inherit is a DESIGNATION mode. Manual's stored-value range is
	NOT preflighted because `forage.gd` publishes no reader for the raw `quota_milli` column; that
	one case reaches the store, which refuses before writing, and is reported under its own code.
	"""
	if not _forage.is_quota_mode(mode):
		return RESULT_ARGUMENT_RANGE
	var is_designation: bool = _forage.is_designation(zone_slot)
	if mode == ForageScript.QUOTA_MODE_AUTOMATIC and is_designation:
		return RESULT_POLICY_NOT_VALID_HERE
	if mode == ForageScript.QUOTA_MODE_INHERIT and not is_designation:
		return RESULT_POLICY_NOT_VALID_HERE
	var applied: ForageScript.OpResult = _forage.set_quota_mode(_forage.zone_ref_of(zone_slot),
		mode, _calendar.season)
	if not applied.ok:
		_store_code = applied.error
		return RESULT_STORE_REFUSED
	_math.succeed(mode)
	return RESULT_COMMITTED


func _commit_zone_enabled(value: int, zone_slot: int) -> int:
	"""Enable or disable one designation's harvesting, keeping the planner's demand in step.

	`forage.gd`'s `enabled` flag and `job_planner.gd`'s demand are two records of one player
	intent, and leaving them disagreeing is how a disabled zone keeps producing work. Both move
	together or neither does: a refused demand change restores the flag it had a moment ago.
	"""
	if _planner == null:
		return RESULT_STORE_NOT_BOUND
	if value != TOGGLE_OFF and value != TOGGLE_ON:
		return RESULT_ARGUMENT_RANGE
	var enable: bool = value == TOGGLE_ON
	var previous: bool = _forage.is_zone_enabled(zone_slot)
	var zone_ref: Vector2i = _forage.zone_ref_of(zone_slot)
	var flagged: ForageScript.OpResult = _forage.set_zone_enabled(zone_ref, enable)
	if not flagged.ok:
		_store_code = flagged.error
		return RESULT_STORE_REFUSED
	var demanded: StringName = _sync_forage_demand(zone_ref, zone_slot, enable)
	if demanded != REFUSE_NONE:
		_forage.set_zone_enabled(zone_ref, previous)
		_store_code = demanded
		return RESULT_STORE_REFUSED
	_math.succeed(value)
	return RESULT_COMMITTED


func _sync_forage_demand(zone_ref: Vector2i, zone_slot: int, enable: bool) -> StringName:
	"""Bring the planner's demand into agreement with the zone flag. Empty name when it agrees.

	Idempotent by construction: a repeat enable of already-enabled demand asks the planner for
	nothing, so the same command twice is one activation rather than a refusal the player did not
	cause. The planner's own repeat-enable refusal is preserved for the case that DOES change.
	"""
	var enabled: bool = _planner.is_forage_demand_enabled(zone_slot)
	if enabled == enable:
		return REFUSE_NONE
	if enable:
		var activated: JobPlannerScript.OpResult = _planner.enable_forage_demand(zone_ref)
		return REFUSE_NONE if activated.ok else activated.error
	var stopped: JobPlannerScript.OpResult = _planner.disable_forage_demand(zone_ref)
	return REFUSE_NONE if stopped.ok else stopped.error


# --- SET_ACTIVITY_SCHEDULE ----------------------------------------------------------------------

func _commit_set_activity_schedule(command: CommandsScript.Command) -> int:
	"""Rewrite one resident's whole 24-hour day from §8.1's schedule bytes.

	The whole day is the schema because it is the only one §8.1 names, and because a whole-day
	write is atomic by construction: 24 bytes are validated, then 24 hours are written. A day
	with one illegal activity byte changes no hour at all.
	"""
	if _schedule == null:
		return RESULT_STORE_NOT_BOUND
	var resolved: int = _resolve_target(command, EntityDirectory.KIND_RESIDENT)
	if resolved != RESULT_COMMITTED:
		return resolved
	var loaded: int = _load_payload(command, SCHEDULE_PAYLOAD_BYTES)
	if loaded != RESULT_COMMITTED:
		return loaded
	if not _schedule.is_present(_target_row):
		_store_code = ScheduleScript.REFUSE_NOT_PRESENT
		return RESULT_STORE_REFUSED
	for hour: int in SCHEDULE_PAYLOAD_BYTES:
		if _payload[hour] >= ACTIVITY_COUNT:
			return RESULT_ARGUMENT_RANGE
	return _write_schedule_day(_target_row)


func _write_schedule_day(slot: int) -> int:
	"""Write all 24 preflighted hours of one resident's day. Every hour is already legal."""
	for hour: int in SCHEDULE_PAYLOAD_BYTES:
		var written: ScheduleScript.OpResult = _schedule.set_hour_activity(slot, hour,
			_payload[hour])
		if not written.ok:
			_store_code = written.error
			return RESULT_STORE_REFUSED
	_math.succeed(SCHEDULE_PAYLOAD_BYTES)
	return RESULT_COMMITTED


# --- SET_JOB_PRIORITIES -------------------------------------------------------------------------

func _commit_set_job_priorities(command: CommandsScript.Command) -> int:
	"""Set one resident's job priorities, and optionally the two consent toggles, atomically.

	Every row and both toggles are validated before the first write, so a list with one illegal
	priority leaves all twelve priorities and both toggles exactly as they were.
	"""
	if _priorities == null:
		return RESULT_STORE_NOT_BOUND
	var resolved: int = _resolve_target(command, EntityDirectory.KIND_RESIDENT)
	if resolved != RESULT_COMMITTED:
		return resolved
	var shaped: int = _group_row_count(command, PRIORITY_ROW_BYTES, JOB_KIND_COUNT)
	if shaped != RESULT_COMMITTED:
		return shaped
	var rows: int = _math.value
	if not _priorities.is_present(_target_row):
		_store_code = PrioritiesScript.REFUSE_NOT_PRESENT
		return RESULT_STORE_REFUSED
	var checked: int = _priority_rows_refusal(rows)
	if checked != RESULT_COMMITTED:
		return checked
	if not _is_toggle(command.arg0) or not _is_toggle(command.arg1):
		return RESULT_ARGUMENT_RANGE
	return _write_priority_rows(_target_row, rows, command.arg0, command.arg1)


func _priority_rows_refusal(rows: int) -> int:
	"""Validate every `(job_kind, priority)` row's domain and ascending owner order, writing nothing.

	The rows must already be sorted by ascending job kind with no repeat: the canonical order is
	refused into existence rather than silently produced, so two callers cannot disagree about
	which of two rows for one kind won.
	"""
	var previous_kind: int = -1
	for index: int in rows:
		var base: int = GROUP_COUNT_BYTES + index * PRIORITY_ROW_BYTES
		var kind: int = _payload.decode_s32(base)
		var priority: int = _payload.decode_s32(base + 4)
		if kind <= previous_kind:
			return RESULT_PAYLOAD_SCHEMA
		previous_kind = kind
		if kind < 0 or kind >= JOB_KIND_COUNT:
			return RESULT_ARGUMENT_RANGE
		if kind == PrioritiesScript.JOB_KIND_RESERVED_INDEX:
			return RESULT_ARGUMENT_RANGE
		if priority < PrioritiesScript.PRIORITY_MIN or priority > PrioritiesScript.PRIORITY_MAX:
			return RESULT_ARGUMENT_RANGE
	return RESULT_COMMITTED


func _write_priority_rows(slot: int, rows: int, fallback: int, dangerous: int) -> int:
	"""Write every preflighted priority row, then whichever of the two toggles was supplied."""
	for index: int in rows:
		var base: int = GROUP_COUNT_BYTES + index * PRIORITY_ROW_BYTES
		var written: PrioritiesScript.OpResult = _priorities.set_priority(slot,
			_payload.decode_s32(base), _payload.decode_s32(base + 4))
		if not written.ok:
			_store_code = written.error
			return RESULT_STORE_REFUSED
	if fallback != TOGGLE_UNCHANGED:
		if not _priorities.set_auto_fallback(slot, fallback == TOGGLE_ON).ok:
			_store_code = PrioritiesScript.REFUSE_NOT_PRESENT
			return RESULT_STORE_REFUSED
	if dangerous != TOGGLE_UNCHANGED:
		if not _priorities.set_dangerous_work(slot, dangerous == TOGGLE_ON).ok:
			_store_code = PrioritiesScript.REFUSE_NOT_PRESENT
			return RESULT_STORE_REFUSED
	_math.succeed(rows)
	return RESULT_COMMITTED


func _is_toggle(value: int) -> bool:
	"""True for the three legal toggle values: leave unchanged, off, on."""
	return value == TOGGLE_UNCHANGED or value == TOGGLE_OFF or value == TOGGLE_ON


# --- NAME_RESIDENT ------------------------------------------------------------------------------

func _commit_name_resident(command: CommandsScript.Command) -> int:
	"""Apply ARCH-SAVE-005's sanitized player alias to one resident.

	"Player aliases are 2-32 Unicode characters with control characters rejected", and malformed
	UTF-8 is rejected. All three are refusals with their own codes; none is a truncation, because
	a silently shortened name is a name the player did not choose.
	"""
	if _residents == null:
		return RESULT_STORE_NOT_BOUND
	var resolved: int = _resolve_target(command, EntityDirectory.KIND_RESIDENT)
	if resolved != RESULT_COMMITTED:
		return resolved
	if command.payload_length < 1 or command.payload_length > ALIAS_MAX_BYTES:
		return RESULT_ALIAS_LENGTH
	var loaded: int = _load_payload(command, command.payload_length)
	if loaded != RESULT_COMMITTED:
		return loaded
	var alias: String = _payload.slice(0, command.payload_length).get_string_from_utf8()
	var refusal: int = _alias_refusal(alias, command.payload_length)
	if refusal != RESULT_COMMITTED:
		return refusal
	var named: ResidentsScript.OpResult = _residents.set_name(_target_row, StringName(alias))
	if not named.ok:
		_store_code = named.error
		return RESULT_STORE_REFUSED
	_math.succeed(alias.length())
	return RESULT_COMMITTED


func _alias_refusal(alias: String, byte_count: int) -> int:
	"""ARCH-SAVE-005's three alias rules, in checked integers. RESULT_COMMITTED when clean.

	Malformed UTF-8 is caught by RE-ENCODING: Godot's decoder substitutes replacement characters
	rather than failing, so a decode that does not round-trip to the original bytes is the only
	honest test available, and it also catches an embedded NUL and an overlong encoding.
	"""
	if alias.to_utf8_buffer().size() != byte_count:
		return RESULT_ALIAS_MALFORMED_UTF8
	if alias.length() < ALIAS_MIN_CHARACTERS or alias.length() > ALIAS_MAX_CHARACTERS:
		return RESULT_ALIAS_LENGTH
	for index: int in alias.length():
		var code_point: int = alias.unicode_at(index)
		if code_point < ASCII_SPACE or code_point == ASCII_DELETE:
			return RESULT_ALIAS_CONTROL_CHARACTER
	return RESULT_COMMITTED


# --- DESIGNATE_ZONE: the one arm that closes the loop from intent to work -----------------------

func _commit_designate_zone(command: CommandsScript.Command) -> int:
	"""Designate a new FORAGE harvest zone inside the targeted ecology basin and demand its harvest.

	The target is the BASIN, because R05-BASIN-002 makes a self-owned zone an ecology basin that
	binds no player intent: `job_planner.gd` refuses demand on anything that is not bound to one.
	So this creates the zone, binds it to the target, links its tiles and enables the demand -- and
	the next ARCH-SYS-009 tick publishes a QUEUED FORAGE Job. `arg0` is the ZoneType and `arg1` the
	§5.5 danger band; the payload is §8.1's "zone tiles", count-prefixed and ascending.
	"""
	var unbound: int = _designate_preflight(command)
	if unbound != RESULT_COMMITTED:
		return unbound
	var tiles: int = _math.value
	var created: ForageScript.OpResult = _forage.create_zone(ForageScript.ZONE_TYPE_FORAGE,
		command.arg1, 0, false, true)
	if not created.ok:
		_store_code = created.error
		return RESULT_STORE_REFUSED
	var bound: int = _bind_designation(created.ref, _forage.zone_ref_of(_target_row), tiles)
	if bound == RESULT_COMMITTED:
		_record_source_intent(command, created.ref)
	return bound


func _designate_preflight(command: CommandsScript.Command) -> int:
	"""Every gate DESIGNATE_ZONE can check before it creates anything. Leaves the tile count in `_math`.

	Allocate before consume (decision 0024): directory capacity, link capacity, the basin's type
	and its own binding are all proved here, so the create/bind/link/enable sequence that follows
	has nothing left that can legitimately refuse.
	"""
	if _forage == null or _planner == null:
		return RESULT_STORE_NOT_BOUND
	var resolved: int = _resolve_target(command, EntityDirectory.KIND_HARVEST_ZONE)
	if resolved != RESULT_COMMITTED:
		return resolved
	if command.arg0 != ForageScript.ZONE_TYPE_FORAGE:
		return RESULT_UNSUPPORTED_FEATURE
	if command.arg1 < ForageScript.DANGER_MIN or command.arg1 > ForageScript.DANGER_MAX:
		return RESULT_ARGUMENT_RANGE
	var basin: int = _basin_refusal(_target_row)
	if basin != RESULT_COMMITTED:
		return basin
	if _live_zone_of_intent(command) != EntityDirectory.NULL_SLOT:
		_duplicate_intent_count += 1
		return RESULT_DUPLICATE_INTENT
	var shaped: int = _group_row_count(command, TILE_ROW_BYTES, ZONE_TILE_MAX_ROWS)
	if shaped != RESULT_COMMITTED:
		return shaped
	var tiles: int = _math.value
	var listed: int = _tile_rows_refusal(tiles)
	if listed != RESULT_COMMITTED:
		return listed
	_math.succeed(tiles)
	return _capacity_refusal(tiles)


func _basin_refusal(basin_slot: int) -> int:
	"""RESULT_COMMITTED when the targeted zone can actually be a FORAGE basin for a new designation.

	`forage.set_basin()` refuses a type mismatch and a basin that is itself bound, because a chain
	would give two answers for one zone's stock. Both are checked here so the refusal happens
	before a zone is created rather than after it and a rollback.
	"""
	var zone_type: IntMath.IntResult = _forage.zone_type_of(basin_slot)
	if not zone_type.ok:
		_store_code = StringName(zone_type.error)
		return RESULT_STORE_REFUSED
	if zone_type.value != ForageScript.ZONE_TYPE_FORAGE:
		return RESULT_BASIN_TYPE
	if _forage.is_designation(basin_slot):
		return RESULT_BASIN_CHAIN
	return RESULT_COMMITTED


func _tile_rows_refusal(tiles: int) -> int:
	"""Validate every tile index against `forage.gd`'s own grid bound and its ascending order.

	No map bound is invented here: `is_tile_index()` is the owning store's predicate over its own
	128x128 exterior grid, which is why decision 0042's unresolved `goal_x`/`goal_z` units are not
	needed and are not read.
	"""
	var previous: int = -1
	for index: int in tiles:
		var tile: int = _payload.decode_s32(GROUP_COUNT_BYTES + index * TILE_ROW_BYTES)
		if tile <= previous:
			return RESULT_ZONE_TILE_UNSORTED
		previous = tile
		if not _forage.is_tile_index(tile):
			return RESULT_ZONE_TILE_RANGE
	return RESULT_COMMITTED


func _capacity_refusal(tiles: int) -> int:
	"""Prove the directory can hand out a HarvestZone row and the link arena can hold every tile."""
	if _directory.free_slot_count() < 1:
		return RESULT_ZONE_CAPACITY
	if _directory.free_row_count(EntityDirectory.KIND_HARVEST_ZONE) < 1:
		return RESULT_ZONE_CAPACITY
	if _forage.link_count() + tiles > ForageScript.ZONE_LINK_CAPACITY:
		return RESULT_ZONE_LINK_CAPACITY
	return RESULT_COMMITTED


func _bind_designation(zone_ref: Vector2i, basin_ref: Vector2i, tiles: int) -> int:
	"""Bind, link and demand a freshly created zone, destroying it whole if any step refuses.

	`forage.destroy_zone()` releases the tile links and the directory slot, so the rollback is the
	owning store's own operation. It cannot return the consumed directory GENERATION -- that is
	the one thing a refusal here leaves changed, and it is neither policy nor goods.
	"""
	var bound: ForageScript.OpResult = _forage.set_basin(zone_ref, basin_ref)
	if not bound.ok:
		return _rollback_designation(zone_ref, bound.error)
	for index: int in tiles:
		var tile: int = _payload.decode_s32(GROUP_COUNT_BYTES + index * TILE_ROW_BYTES)
		var linked: ForageScript.OpResult = _forage.add_tile(zone_ref, tile)
		if not linked.ok:
			return _rollback_designation(zone_ref, linked.error)
	var enabled: JobPlannerScript.OpResult = _planner.enable_forage_demand(zone_ref)
	if not enabled.ok:
		return _rollback_designation(zone_ref, enabled.error)
	_math.succeed(enabled.value)
	return RESULT_COMMITTED


func _rollback_designation(zone_ref: Vector2i, code: StringName) -> int:
	"""Destroy the zone this command created and report the store code that stopped it."""
	_forage.destroy_zone(zone_ref)
	_store_code = code
	return RESULT_STORE_REFUSED


# --- the source-intent ledger (task 04.4: one player intent, at most one designation) ----------

func _live_zone_of_intent(command: CommandsScript.Command) -> int:
	"""The zone row this exact player command already produced, or NULL_SLOT if none is alive.

	ARCH-CMD-001 identifies one player command by `(player_id, sequence_high, sequence_low)`, and
	that is the whole key here: two commands with DIFFERENT sequences over the same basin and the
	same tiles are two genuine intents, because `forage.gd` states that "§5.1's overlapping
	designations are the case the per-tile list exists for". What may not happen twice is ONE
	intent producing two designations, which a replayed or redelivered envelope does today.

	The generation is compared as well as the row: a destroyed designation whose row the directory
	has handed to another entity is NOT this intent's designation, and re-running the intent then
	creates a genuinely new one.
	"""
	for slot: int in INTENT_CAPACITY:
		if _intent_player_id[slot] != command.player_id:
			continue
		if _intent_sequence_high[slot] != command.sequence_high:
			continue
		if _intent_sequence_low[slot] != command.sequence_low:
			continue
		if _forage.zone_ref_of(slot).y != _intent_zone_generation[slot]:
			continue
		return slot
	return EntityDirectory.NULL_SLOT


func _record_source_intent(command: CommandsScript.Command, zone_ref: Vector2i) -> void:
	"""Stamp the command identity that produced one designation onto that designation's row."""
	var slot: int = _directory.get_typed_row(zone_ref)
	_intent_player_id[slot] = command.player_id
	_intent_sequence_high[slot] = command.sequence_high
	_intent_sequence_low[slot] = command.sequence_low
	_intent_zone_generation[slot] = zone_ref.y


func source_intent_count() -> int:
	"""Player intents that still own a live designation. The acceptance measure of "one intent"."""
	var live: int = 0
	for slot: int in INTENT_CAPACITY:
		if _intent_player_id[slot] == NO_INTENT_PLAYER:
			continue
		if _forage != null and _forage.zone_ref_of(slot).y == _intent_zone_generation[slot]:
			live += 1
	return live


func has_source_intent(zone_slot: int) -> bool:
	"""True when a player command produced the designation currently in this zone row."""
	if zone_slot < 0 or zone_slot >= INTENT_CAPACITY or _forage == null:
		return false
	if _intent_player_id[zone_slot] == NO_INTENT_PLAYER:
		return false
	return _forage.zone_ref_of(zone_slot).y == _intent_zone_generation[zone_slot]


func source_intent_into(zone_slot: int, out: IntentRow) -> bool:
	"""Copy one designation's originating command identity into a record the CALLER owns.

	A copy, never a handle: this is what a UI shows when it names which order created a zone, and
	it carries no reference to the ledger.
	"""
	if not has_source_intent(zone_slot):
		_last_refusal = REFUSE_NO_SOURCE_INTENT
		return false
	out.zone_slot = zone_slot
	out.zone_generation = _intent_zone_generation[zone_slot]
	out.player_id = _intent_player_id[zone_slot]
	out.sequence_high = _intent_sequence_high[zone_slot]
	out.sequence_low = _intent_sequence_low[zone_slot]
	return true


func duplicate_intent_count() -> int:
	"""Commands refused because their source intent had already produced a live designation."""
	return _duplicate_intent_count


# --- presentation projections: copies, never handles ---------------------------------------------

func pending_count() -> int:
	"""How many accepted commands are queued and not yet committed."""
	return _queue.pending_count()


func pending_into(position: int, out: PendingRow) -> bool:
	"""Copy one queued command into a record the CALLER owns. Position 0 is the next to execute.

	This is the ghost row a paused settlement draws. It carries no reference to the queue, so a
	presentation layer holding it cannot reorder, cancel or edit anything.
	"""
	if not _queue.read_into(position, _drained):
		_last_refusal = _queue.last_refusal()
		return false
	out.execute_tick = _drained.execute_tick
	out.sequence_low = _drained.sequence_low
	out.sequence_high = _drained.sequence_high
	out.kind = _drained.kind
	out.target_slot = _drained.target_slot
	out.target_generation = _drained.target_generation
	out.arg0 = _drained.arg0
	out.arg1 = _drained.arg1
	out.payload_length = _drained.payload_length
	out.is_cancellation = _drained.kind == KIND_CANCEL_JOB or _drained.kind == KIND_CANCEL_MANUAL
	out.is_supported = is_supported_kind(_drained.kind)
	_last_refusal = REFUSE_NONE
	return true


func result_count() -> int:
	"""How many outcomes the ledger currently retains, at most one per queued command."""
	return _result_count


func result_into(index: int, out: ResultRow) -> bool:
	"""Copy one retained outcome into a caller-owned record. Index 0 is the oldest retained."""
	if index < 0 or index >= _result_count:
		_last_refusal = REFUSE_INVALID_RESULT_ID
		return false
	var row: int = (_result_write - _result_count + index + RESULT_CAPACITY) % RESULT_CAPACITY
	out.execute_tick = _result_execute_tick[row]
	out.sequence_low = _result_sequence_low[row]
	out.sequence_high = _result_sequence_high[row]
	out.kind = _result_kind[row]
	out.code_id = _result_code[row]
	out.value = _result_value[row]
	out.target_slot = _result_target_slot[row]
	out.target_generation = _result_target_generation[row]
	out.store_code = _result_store_code[row]
	_last_refusal = REFUSE_NONE
	return true


func last_result_into(out: ResultRow) -> bool:
	"""Copy the most recent outcome, which is what a refusal banner shows."""
	return result_into(_result_count - 1, out)


# --- the documented refusal domain ---------------------------------------------------------------

func result_code(code_id: int) -> StringName:
	"""The StringName of a deterministic result id, or the empty name for an id outside the domain.

	The empty name is ABSENCE, not a refusal channel: `is_result_id()` is the predicate, exactly
	as `catalog.gd` separates an unknown key from a compiled one.
	"""
	if not is_result_id(code_id):
		return REFUSE_NONE
	return RESULT_CODES[code_id]


func is_result_id(code_id: int) -> bool:
	"""True for one of the documented, ASCII-sorted result ids."""
	return code_id >= 0 and code_id < RESULT_COUNT


func result_code_id(code: StringName) -> int:
	"""The deterministic id of a result code, refusing an unknown one rather than inventing one.

	Returns through `_math`-free integer search over a 21-entry sorted domain; the caller must
	call `is_result_id()` on the answer, which is false for an unknown code.
	"""
	for index: int in RESULT_COUNT:
		if RESULT_CODES[index] == code:
			return index
	return RESULT_COUNT


func is_supported_kind(kind: int) -> bool:
	"""True when this ARCH-CMD-003 kind has an implemented owning store in this build."""
	if kind < 0 or kind >= KIND_COUNT:
		return false
	return UNSUPPORTED_REASON[kind] == REFUSE_NONE


func unsupported_reason(kind: int) -> StringName:
	"""Which owning store or contract is missing for an unimplemented kind. Empty when supported."""
	if kind < 0 or kind >= KIND_COUNT:
		return REFUSE_NONE
	return UNSUPPORTED_REASON[kind]


func supported_kind_count() -> int:
	"""How many of ARCH-CMD-003's 24 kinds this build actually commits."""
	var supported: int = 0
	for kind: int in KIND_COUNT:
		if is_supported_kind(kind):
			supported += 1
	return supported


# --- counters and diagnostics ---------------------------------------------------------------------

func committed_count() -> int:
	"""How many commands this dispatcher has committed since `clear()`."""
	return _committed_count


func refused_count() -> int:
	"""How many commands this dispatcher has refused since `clear()`."""
	return _refused_count


func results_recorded() -> int:
	"""How many outcomes have been recorded, including those the ring has since overwritten."""
	return _results_recorded


func result_capacity() -> int:
	"""How many outcomes the ledger retains before the oldest is overwritten."""
	return RESULT_CAPACITY


func ledger_bytes() -> int:
	"""Bytes this dispatcher allocates beyond §2.3's existing rows, for the memory ledger."""
	return _result_execute_tick.size() * 8 + 7 * _result_sequence_low.size() * 4 \
		+ _result_store_code.size() * 8 + _payload.size()


func last_refusal() -> StringName:
	"""The most recent stage-level refusal, or the empty name after a successful stage."""
	return _last_refusal


func queue() -> CommandsScript:
	"""The ordered command queue this dispatcher drains, so a caller can submit to exactly it."""
	return _queue


func directory() -> EntityDirectory:
	"""The one directory every bound store and every target reference is validated against."""
	return _directory
