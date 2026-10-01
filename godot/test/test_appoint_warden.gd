extends "res://test/framework/test_case.gd"
## REQ-SET-157's Warden succession: `residents.gd::appoint_warden()` and the APPOINT_WARDEN arm of
## `command_dispatch.gd` (decision 0511).
##
## THE DEFINED PART ONLY. REQ-SET-157: "When Warden Rowan or a later Warden dies/leaves, the
## system shall allow appointment of any living resident and preserve the settlement." GDD §5.11:
## "Warden death alone does not end play; player can appoint another adult, with no stat change."
## Only a living ADULT satisfies both sentences, and only a vacant seat is named by either, so a
## CHILD, an ELDER and a living Warden's replacement each refuse with their own code -- tested
## below by value -- rather than being decided here.
##
## THE CONSTANTS ARE TRANSCRIBED FROM THE DOCUMENTS: Role RESIDENT=0/WARDEN=1/SPECIALIST=2 is GDD
## §4.3's table, life stage ADULT=0/CHILD=1/ELDER=2 is MOVE-DEP-R02, and APPOINT_WARDEN=1 is
## ARCH-CMD-003's sorted list.

const CommandsScript := preload("res://scripts/core/commands.gd")
const CommandDispatchScript := preload("res://scripts/core/command_dispatch.gd")
const EntityDirectory := preload("res://scripts/core/entity_directory.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const NeedsScript := preload("res://scripts/core/needs.gd")
const ResidentsScript := preload("res://scripts/core/residents.gd")
const SimClockScript := preload("res://scripts/core/sim_clock.gd")

const KIND_APPOINT_WARDEN: int = 1
const ROLE_RESIDENT: int = 0
const ROLE_WARDEN: int = 1
const ROLE_SPECIALIST: int = 2
const STAGE_ADULT: int = 0
const STAGE_CHILD: int = 1
const STAGE_ELDER: int = 2
const SKILL_COUNT: int = 12
const COMMIT_TICK: int = 1

var _residents: ResidentsScript = null
var _clock: SimClockScript = null
var _queue: CommandsScript = null
var _dispatch: CommandDispatchScript = null
var _submission: CommandsScript.Command = null
var _submit_result: CommandsScript.SubmitResult = null
var _report: CommandDispatchScript.TickReport = null
var _row: CommandDispatchScript.ResultRow = null


func before_each() -> void:
	"""One residents store and a dispatcher bound to it over the store's own directory."""
	_residents = ResidentsScript.new()
	_clock = SimClockScript.new()
	_queue = CommandsScript.new(_clock, _residents.directory())
	_dispatch = CommandDispatchScript.new(_queue, _residents)
	_submission = CommandsScript.Command.new()
	_submit_result = CommandsScript.SubmitResult.new()
	_report = CommandDispatchScript.TickReport.new()
	_row = CommandDispatchScript.ResultRow.new()


func after_each() -> void:
	"""Drop every store so no test inherits another's rows."""
	_dispatch = null
	_queue = null
	_clock = null
	_residents = null


# --- fixture helpers ----------------------------------------------------------------------------

func _spawn(stage: int = STAGE_ADULT) -> int:
	"""Spawn one mouse at `stage` and return its row."""
	var spawned: ResidentsScript.OpResult = _residents.spawn_with_stage(&"mouse", stage)
	assert_true(spawned.ok, "the resident spawns (error: %s)" % spawned.error)
	return spawned.value


func _kill(slot: int) -> void:
	"""Take a resident's health to 0, which §5.2 commits as death on the retained row."""
	assert_true(_residents.needs().apply_health_event(slot, -NeedsScript.HEALTH_MAX).ok,
		"the resident's health reaches 0")
	assert_false(_residents.is_alive(slot), "and the resident is dead")
	assert_true(_residents.is_present(slot), "on a row that is still retained")


func _role(slot: int) -> int:
	"""The stored Role byte of a present row."""
	var role: IntMath.IntResult = _residents.role_of(slot)
	assert_true(role.ok, "the role is readable (error: %s)" % role.error)
	return role.value


func _rowan_has_died() -> int:
	"""A Warden in row 0 who has died, so the seat is vacant. Returns the dead Warden's row."""
	var rowan: int = _spawn()
	assert_true(_residents.set_role(rowan, ROLE_WARDEN).ok, "row 0 is the Warden")
	_kill(rowan)
	return rowan


func _submit(target_slot: int, arg0: int = 0, arg1: int = 0,
		payload: PackedByteArray = PackedByteArray()) -> bool:
	"""Submit one APPOINT_WARDEN naming the current reference of `target_slot`."""
	var ref: Vector2i = _residents.ref_of(target_slot)
	_submission.reset()
	_submission.kind = KIND_APPOINT_WARDEN
	_submission.target_slot = ref.x
	_submission.target_generation = ref.y
	_submission.arg0 = arg0
	_submission.arg1 = arg1
	_submission.payload = payload
	return _queue.submit_into(_submission, _submit_result)


func _commit() -> int:
	"""Run one CommandCommit stage and return how many commands committed."""
	assert_true(_dispatch.commit_tick_into(COMMIT_TICK, _report),
		"the commit stage runs (error: %s)" % _report.error)
	return _report.committed


func _last() -> CommandDispatchScript.ResultRow:
	"""The ledger row of the most recent outcome."""
	assert_true(_dispatch.last_result_into(_row), "the ledger holds an outcome")
	return _row


func _skill_image(slot: int) -> PackedInt64Array:
	"""Every skill's XP and level for one row, so "no stat change" is checked by value."""
	var image: PackedInt64Array = PackedInt64Array()
	for skill: int in SKILL_COUNT:
		if skill == ResidentsScript.SKILL_RESERVED_INDEX:
			continue
		image.append(_residents.skill_xp_of(slot, skill).value)
		image.append(_residents.skill_level_of(slot, skill).value)
	return image


func _assert_store_refusal(code: StringName, why: String) -> void:
	"""The command refused as a store refusal carrying `residents.gd`'s own code."""
	assert_equal(_commit(), 0, "%s: nothing commits" % why)
	var row: CommandDispatchScript.ResultRow = _last()
	assert_equal(row.code_id, CommandDispatchScript.RESULT_STORE_REFUSED,
		"%s: the ledger says the store refused" % why)
	assert_equal(row.store_code, code, "%s: and names the store's reason" % why)


# --- the store: residents.gd::appoint_warden() --------------------------------------------------

func test_a_living_adult_is_appointed_once_the_warden_has_died() -> void:
	"""REQ-SET-157's core sentence: after the Warden dies, any living adult may be appointed."""
	var rowan: int = _rowan_has_died()
	var heir: int = _spawn()
	assert_equal(_residents.serving_warden_slot(), EntityDirectory.NULL_SLOT,
		"a dead Warden does not serve, so the seat is vacant")
	var appointed: ResidentsScript.OpResult = _residents.appoint_warden(heir)
	assert_true(appointed.ok, "the appointment succeeds (error: %s)" % appointed.error)
	assert_equal(_role(heir), ROLE_WARDEN, "the heir now holds the WARDEN role")
	assert_equal(_residents.serving_warden_slot(), heir, "and is the serving Warden")
	assert_equal(_role(rowan), ROLE_WARDEN, "the dead Warden's retained row keeps its history")


func test_appointment_changes_no_stat() -> void:
	"""§5.11: "player can appoint another adult, with no stat change". Only the role byte moves."""
	_rowan_has_died()
	var heir: int = _spawn()
	assert_true(_residents.set_skill_xp(heir, 0, 30000).ok, "the heir has earned some XP")
	var skills: PackedInt64Array = _skill_image(heir)
	var health: int = _residents.needs().health_of(heir).value
	var named: bool = _residents.is_named(heir)
	assert_true(_residents.appoint_warden(heir).ok, "the appointment succeeds")
	assert_equal(_skill_image(heir), skills, "every skill's XP and level is unchanged")
	assert_equal(_residents.needs().health_of(heir).value, health, "health is unchanged")
	assert_equal(_residents.is_named(heir), named, "and naming is not decided by this path")
	assert_equal(_residents.life_stage_of(heir).value, STAGE_ADULT, "nor is the stage")


func test_a_settlement_with_no_warden_at_all_can_appoint_one() -> void:
	"""A vacant seat is vacant however it became so; nobody needs to have died first."""
	var first: int = _spawn()
	assert_true(_residents.appoint_warden(first).ok, "the vacant seat is filled")
	assert_equal(_residents.serving_warden_slot(), first, "by the appointee")


func test_a_living_warden_is_not_replaced() -> void:
	"""Replacing a LIVING Warden is specified nowhere, so it refuses and deposes nobody."""
	var rowan: int = _spawn()
	assert_true(_residents.set_role(rowan, ROLE_WARDEN).ok, "row 0 is the living Warden")
	var rival: int = _spawn()
	var refused: ResidentsScript.OpResult = _residents.appoint_warden(rival)
	assert_false(refused.ok, "the appointment refuses")
	assert_equal(refused.error, ResidentsScript.REFUSE_WARDEN_SEAT_OCCUPIED, "as an occupied seat")
	assert_equal(_role(rival), ROLE_RESIDENT, "the rival is still an ordinary resident")
	assert_equal(_role(rowan), ROLE_WARDEN, "and the Warden still serves")


func test_the_serving_warden_cannot_be_appointed_again() -> void:
	"""Re-appointing the sitting Warden is the same occupied seat, not a silent success."""
	var rowan: int = _spawn()
	assert_true(_residents.appoint_warden(rowan).ok, "the first appointment succeeds")
	assert_equal(_residents.appoint_warden(rowan).error,
		ResidentsScript.REFUSE_WARDEN_SEAT_OCCUPIED, "a second one refuses")


func test_an_incapacitated_warden_still_holds_the_seat() -> void:
	"""Health 1-15 is INCAPACITATED, not dead: REQ-SET-157 opens the seat on death or departure."""
	var rowan: int = _spawn()
	assert_true(_residents.set_role(rowan, ROLE_WARDEN).ok, "row 0 is the Warden")
	assert_true(_residents.needs().apply_health_event(rowan, -NeedsScript.HEALTH_MAX + 1).ok,
		"the Warden is at health 1")
	assert_true(_residents.is_alive(rowan), "and still alive")
	var heir: int = _spawn()
	assert_equal(_residents.appoint_warden(heir).error,
		ResidentsScript.REFUSE_WARDEN_SEAT_OCCUPIED, "so the seat is not vacant")


func test_a_dead_resident_cannot_be_appointed() -> void:
	"""REQ-SET-157 says a LIVING resident. A retained dead row is refused by its own code."""
	_rowan_has_died()
	var fallen: int = _spawn()
	_kill(fallen)
	var refused: ResidentsScript.OpResult = _residents.appoint_warden(fallen)
	assert_equal(refused.error, ResidentsScript.REFUSE_WARDEN_CANDIDATE_NOT_LIVING,
		"the dead candidate is refused as not living")
	assert_equal(_role(fallen), ROLE_RESIDENT, "and its role byte is untouched")


func test_a_child_and_an_elder_refuse_as_unruled_stages() -> void:
	"""Only ADULT satisfies both REQ-SET-157 and §5.11; the other two stages await a ruling."""
	_rowan_has_died()
	for stage: int in [STAGE_CHILD, STAGE_ELDER]:
		var candidate: int = _spawn(stage)
		var refused: ResidentsScript.OpResult = _residents.appoint_warden(candidate)
		assert_equal(refused.error, ResidentsScript.REFUSE_WARDEN_CANDIDATE_STAGE,
			"stage %d refuses as unruled" % stage)
		assert_equal(_role(candidate), ROLE_RESIDENT, "stage %d keeps its role" % stage)
	assert_equal(_residents.serving_warden_slot(), EntityDirectory.NULL_SLOT,
		"and the seat is still vacant")


func test_a_free_row_refuses_as_not_present() -> void:
	"""A row nobody occupies has no resident to appoint."""
	assert_equal(_residents.appoint_warden(7).error, ResidentsScript.REFUSE_NOT_PRESENT,
		"an empty row refuses")
	assert_equal(_residents.appoint_warden(-1).error, ResidentsScript.REFUSE_NOT_PRESENT,
		"and so does an out-of-range one")


func test_a_specialist_is_eligible_and_the_one_role_byte_becomes_warden() -> void:
	"""Role is ONE enum per §4.3, so an appointed SPECIALIST becomes WARDEN; decision 0511 says so."""
	_rowan_has_died()
	var specialist: int = _spawn()
	assert_true(_residents.set_role(specialist, ROLE_SPECIALIST).ok, "a specialist")
	assert_true(_residents.appoint_warden(specialist).ok, "is a living adult and is eligible")
	assert_equal(_role(specialist), ROLE_WARDEN, "and now holds the WARDEN role")


func test_the_serving_warden_is_the_lowest_living_warden_row() -> void:
	"""A dead Warden in a lower row is skipped; the living one above it is the one serving."""
	var rowan: int = _rowan_has_died()
	var heir: int = _spawn()
	assert_true(_residents.appoint_warden(heir).ok, "the heir is appointed")
	assert_true(rowan < heir, "the dead Warden sits in the lower row")
	assert_equal(_residents.serving_warden_slot(), heir, "and does not shadow the living one")


func test_two_living_wardens_answer_with_the_lowest_row() -> void:
	"""`set_role()` can write a second WARDEN byte; the reader is still deterministic about it."""
	var first: int = _spawn()
	var second: int = _spawn()
	assert_true(_residents.set_role(second, ROLE_WARDEN).ok, "the higher row is a Warden")
	assert_true(_residents.set_role(first, ROLE_WARDEN).ok, "and so, by a raw setter, is the lower")
	assert_equal(_residents.serving_warden_slot(), first, "the lowest living row answers")


func test_the_refusal_order_is_presence_then_life_then_stage_then_seat() -> void:
	"""Decision 0511's order, pinned while a living Warden makes the LAST refusal always true."""
	var rowan: int = _spawn()
	assert_true(_residents.set_role(rowan, ROLE_WARDEN).ok, "a living Warden serves")
	assert_equal(_residents.appoint_warden(-1).error, ResidentsScript.REFUSE_NOT_PRESENT,
		"a free row is refused for presence before the occupied seat")
	var dead_adult: int = _spawn()
	_kill(dead_adult)
	assert_equal(_residents.appoint_warden(dead_adult).error,
		ResidentsScript.REFUSE_WARDEN_CANDIDATE_NOT_LIVING, "a dead adult for life before the seat")
	var dead_child: int = _spawn(STAGE_CHILD)
	_kill(dead_child)
	assert_equal(_residents.appoint_warden(dead_child).error,
		ResidentsScript.REFUSE_WARDEN_CANDIDATE_NOT_LIVING, "a dead child for life before stage")
	var child: int = _spawn(STAGE_CHILD)
	assert_equal(_residents.appoint_warden(child).error,
		ResidentsScript.REFUSE_WARDEN_CANDIDATE_STAGE, "a living child for stage before the seat")


func test_both_warden_bytes_survive_a_section_four_round_trip() -> void:
	"""The appointment persists through `residents.gd`'s existing section 4 columns, unchanged.

	A dead Warden's retained byte and the appointee's byte both travel; nothing on restore
	refuses two WARDEN bytes, because only the domain 0..2 is validated.
	"""
	var rowan: int = _rowan_has_died()
	var heir: int = _spawn()
	assert_true(_residents.appoint_warden(heir).ok, "the heir is appointed")
	var columns: ResidentsScript.Columns = ResidentsScript.Columns.new()
	assert_true(_residents.copy_columns_into(columns), "section 4 is captured")
	assert_equal([columns.role[rowan], columns.role[heir]], [ROLE_WARDEN, ROLE_WARDEN],
		"both role bytes are in the captured image")
	var target: ResidentsScript = ResidentsScript.new(_directory_copy(), null)
	assert_true(target.restore_columns(columns),
		"the image restores (refusal: %s)" % target.last_column_refusal())
	assert_equal([target.role_of(rowan).value, target.role_of(heir).value],
		[ROLE_WARDEN, ROLE_WARDEN], "and both bytes are restored")


func _directory_copy() -> EntityDirectory:
	"""Section 3 moved to a fresh directory through its own bulk column API."""
	var cap: int = EntityDirectory.DIRECTORY_CAPACITY
	var active: PackedByteArray = PackedByteArray()
	var retired: PackedByteArray = PackedByteArray()
	var generation: PackedInt32Array = PackedInt32Array()
	var persistent_id: PackedInt32Array = PackedInt32Array()
	var kind: PackedInt32Array = PackedInt32Array()
	var typed_row: PackedInt32Array = PackedInt32Array()
	active.resize(cap)
	retired.resize(cap)
	generation.resize(cap)
	persistent_id.resize(cap)
	kind.resize(cap)
	typed_row.resize(cap)
	assert_true(_residents.directory().copy_columns_into(active, generation, retired,
		persistent_id, kind, typed_row), "section 3 is captured")
	var target: EntityDirectory = EntityDirectory.new()
	assert_true(target.restore_columns(active, generation, retired, persistent_id, kind,
		typed_row), "section 3 restores into a fresh directory")
	return target


# --- the command: APPOINT_WARDEN through ARCH-SYS-002 -------------------------------------------

func test_appoint_warden_is_an_implemented_kind_with_no_missing_owner() -> void:
	"""It is now one of the seven, and no longer names a missing contract."""
	assert_true(_dispatch.is_supported_kind(KIND_APPOINT_WARDEN), "APPOINT_WARDEN is implemented")
	assert_equal(_dispatch.unsupported_reason(KIND_APPOINT_WARDEN), &"", "and names no gap")
	assert_equal(_dispatch.supported_kind_count(), 7, "seven of the 24 kinds are implemented")


func test_an_appoint_warden_command_commits_the_appointment() -> void:
	"""Submitted, drained and committed: the targeted heir is the Warden after the stage."""
	_rowan_has_died()
	var heir: int = _spawn()
	assert_true(_submit(heir), "the command is admitted")
	assert_equal(_commit(), 1, "it commits")
	var row: CommandDispatchScript.ResultRow = _last()
	assert_equal(row.code_id, CommandDispatchScript.RESULT_COMMITTED, "as COMMAND_COMMITTED")
	assert_equal(row.value, heir, "with the appointee's row as its value")
	assert_equal(_role(heir), ROLE_WARDEN, "and the heir is the Warden")


func test_an_appoint_warden_command_against_a_living_warden_refuses() -> void:
	"""The store's occupied-seat refusal reaches the ledger with its own code."""
	var rowan: int = _spawn()
	assert_true(_residents.set_role(rowan, ROLE_WARDEN).ok, "a living Warden")
	var rival: int = _spawn()
	assert_true(_submit(rival), "the command is admitted")
	_assert_store_refusal(ResidentsScript.REFUSE_WARDEN_SEAT_OCCUPIED, "occupied seat")
	assert_equal(_role(rival), ROLE_RESIDENT, "the rival is untouched")


func test_an_appoint_warden_command_naming_a_dead_resident_refuses() -> void:
	"""Death between admission and commit is caught at commit, by the store's liveness rule."""
	_rowan_has_died()
	var heir: int = _spawn()
	assert_true(_submit(heir), "the command is admitted while the heir lives")
	_kill(heir)
	_assert_store_refusal(ResidentsScript.REFUSE_WARDEN_CANDIDATE_NOT_LIVING, "dead heir")


func test_an_appoint_warden_command_naming_a_child_refuses_as_unruled() -> void:
	"""The stage refusal reaches the ledger as the store's code, not as a generic failure."""
	_rowan_has_died()
	var child: int = _spawn(STAGE_CHILD)
	assert_true(_submit(child), "the command is admitted")
	_assert_store_refusal(ResidentsScript.REFUSE_WARDEN_CANDIDATE_STAGE, "child")


func test_an_appoint_warden_command_with_a_stale_target_refuses() -> void:
	"""A resident despawned after admission is a stale target, never its slot's next tenant."""
	_rowan_has_died()
	var heir: int = _spawn()
	var ref: Vector2i = _residents.ref_of(heir)
	assert_true(_submit(heir), "the command is admitted")
	assert_true(_residents.despawn(ref).ok, "the heir's row is released")
	var reused: int = _spawn()
	assert_equal(reused, heir, "and the very same row is handed back out")
	assert_equal(_commit(), 0, "the command refuses")
	assert_equal(_last().code_id, CommandDispatchScript.RESULT_TARGET_STALE, "as a stale target")
	assert_equal(_role(reused), ROLE_RESIDENT, "and the new tenant is not appointed")


func test_an_appoint_warden_command_with_the_null_target_refuses() -> void:
	"""REQ-SET-157 names a person; the null reference names nobody."""
	_submission.reset()
	_submission.kind = KIND_APPOINT_WARDEN
	assert_true(_queue.submit_into(_submission, _submit_result), "the envelope is admissible")
	assert_equal(_commit(), 0, "but it refuses")
	assert_equal(_last().code_id, CommandDispatchScript.RESULT_TARGET_REQUIRED, "as target required")


func test_an_appoint_warden_command_with_an_argument_refuses() -> void:
	"""Decision 0511's schema reserves both arguments at 0; a nonzero one is refused, not ignored."""
	_rowan_has_died()
	var heir: int = _spawn()
	assert_true(_submit(heir, 1, 0), "arg0 = 1 is admissible")
	assert_true(_submit(heir, 0, -1), "and so is arg1 = -1")
	assert_equal(_commit(), 0, "neither commits")
	assert_equal(_last().code_id, CommandDispatchScript.RESULT_ARGUMENT_RANGE, "as argument range")
	assert_equal(_dispatch.refused_count(), 2, "both refused")
	assert_equal(_role(heir), ROLE_RESIDENT, "and nobody was appointed")


func test_an_appoint_warden_command_with_a_payload_refuses() -> void:
	"""The identity is the whole command, so a nonempty payload is refused rather than ignored."""
	_rowan_has_died()
	var heir: int = _spawn()
	assert_true(_submit(heir, 0, 0, PackedByteArray([1, 0, 0, 0])), "the payload is admissible")
	assert_equal(_commit(), 0, "but the command refuses")
	assert_equal(_last().code_id, CommandDispatchScript.RESULT_PAYLOAD_SCHEMA, "as payload schema")
	assert_equal(_role(heir), ROLE_RESIDENT, "and nobody was appointed")


func test_an_unbound_residents_store_refuses_rather_than_committing() -> void:
	"""A dispatcher composed without residents cannot appoint anybody, and says so."""
	var bare: CommandDispatchScript = CommandDispatchScript.new(_queue)
	var heir: int = _spawn()
	assert_true(_submit(heir), "the command is admitted")
	assert_true(bare.commit_tick_into(COMMIT_TICK, _report), "the stage runs")
	assert_true(bare.last_result_into(_row), "and records an outcome")
	assert_equal(_row.code_id, CommandDispatchScript.RESULT_STORE_NOT_BOUND, "store not bound")
	assert_equal(_role(heir), ROLE_RESIDENT, "and the role is untouched")
