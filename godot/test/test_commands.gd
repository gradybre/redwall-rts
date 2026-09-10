extends "res://test/framework/test_case.gd"
## Coverage for `scripts/core/commands.gd`: ARCH-CMD-001's ordering, ARCH-CMD-003's compiled kind
## domain, and §8.1's 64-byte record layout.
##
## THE OFFSETS BELOW ARE HARD-CODED LITERALS ON PURPOSE. Reading them from the module's own
## constants would make the assertion a tautology: a mutated `OFFSET_KIND` would move the field and
## move the expectation with it. §8.1's table is transcribed here independently, so a moved field
## fails on a byte value.
##
## THE SIGNED-COMPARISON CASE IS THE ONE THIS MODULE IS MOST LIKELY TO GET WRONG.
## `test_sequence_order_is_unsigned_across_the_sign_bit()` queues sequence 0x7fffffff and then
## 0x80000000 -- the second is a NEGATIVE i32 -- and asserts they drain in that order. Delete the
## `& 0xffffffff` in `compare_key_parts()` and it fails on `arg0`, not on a message.

const Commands := preload("res://scripts/core/commands.gd")
const CatalogScript := preload("res://scripts/core/catalog.gd")
const EntityDirectory := preload("res://scripts/core/entity_directory.gd")
const SimClockScript := preload("res://scripts/core/sim_clock.gd")

## ARCH-CMD-003's list, transcribed from the architecture document in its printed order, which is
## also its ASCII order. Independent of catalog.gd's own table.
const ARCH_CMD_003_KINDS: Array[String] = [
	"ACCEPT_CANDIDATES", "APPOINT_WARDEN", "ASSIGN_BED", "CANCEL_JOB", "CANCEL_MANUAL",
	"CONFIRM_FEAST", "DEMOLISH", "DESIGNATE_ROOM", "DESIGNATE_ZONE", "EDIT_ORDER", "EQUIP",
	"NAME_RESIDENT", "PLACE_BLUEPRINT", "PLACE_FURNITURE", "REQUEST_RELIEF_SEEDS",
	"SET_ACTIVITY_SCHEDULE", "SET_DOOR_OPEN", "SET_FIELD_ROTATION", "SET_JOB_PRIORITIES",
	"SET_MANUAL_TASK", "SET_POLICY", "SET_STORE_FILTER", "SET_STORE_MINIMUM", "UPGRADE",
]

var _queue: Commands = null
var _clock: SimClockScript = null
var _directory: EntityDirectory = null
var _result: Commands.SubmitResult = null
var _read: Commands.Command = null


func before_each() -> void:
	"""A fresh queue over a fresh clock and directory before every test method."""
	_clock = SimClockScript.new()
	_directory = EntityDirectory.new()
	_queue = Commands.new(_clock, _directory)
	_result = Commands.SubmitResult.new()
	_read = Commands.Command.new()


# --- helpers ---------------------------------------------------------------------------------------

func _kind(key: String) -> int:
	"""The compiled ARCH-CMD-003 id of one kind key, read from the catalog and never mirrored."""
	return int(CatalogScript.COMMAND_KIND[key])


func _command(kind_key: String, arg0: int) -> Commands.Command:
	"""A minimal valid envelope of the named kind, marked with `arg0` so it is identifiable."""
	var command: Commands.Command = Commands.Command.new()
	command.kind = _kind(kind_key)
	command.arg0 = arg0
	return command


func _submit(kind_key: String, arg0: int) -> bool:
	"""Submit one minimal command of the named kind."""
	return _queue.submit_into(_command(kind_key, arg0), _result)


func _arg0_at(position: int) -> int:
	"""`arg0` of the queued command at `position`, or -1 when the position does not exist."""
	if not _queue.read_into(position, _read):
		return -1
	return _read.arg0


func _snapshot() -> PackedByteArray:
	"""Every queued record encoded end to end: the bytes a group refusal must not change."""
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(_queue.pending_count() * Commands.RECORD_BYTES)
	for position: int in _queue.pending_count():
		assert_true(_queue.encode_record_into(position, bytes,
			position * Commands.RECORD_BYTES), "encoding position %d" % position)
	return bytes


func _live_ref() -> Vector2i:
	"""One live resident EntityRef from the shared directory."""
	return _directory.create(EntityDirectory.KIND_RESIDENT)


func _run_one_tick() -> void:
	"""Complete exactly one simulation tick on the shared clock."""
	_clock.set_pause(SimClockScript.PLAYER, false)
	var before: int = _clock.completed_tick()
	while _clock.completed_tick() == before:
		_clock.advance(33334)


# --- §8.1's record layout ---------------------------------------------------------------------------

func test_every_field_sits_at_its_own_section_8_1_offset() -> void:
	"""§8.1's table, offset by offset, against a record whose fields are all distinguishable.

	Every field carries a different value, and only `reserved_zero` is 0, so moving any field onto
	another field's offset changes a byte this reads. `encode_command_into()` is the pure encoder,
	which is why `player_id` and `flags` may hold values the QUEUE would refuse.
	"""
	var command: Commands.Command = _command("UPGRADE", 0)
	command.execute_tick = 0x1122334455667788
	command.player_id = 9
	command.flags = 12345
	command.sequence_low = 0x0a0b0c0d
	command.sequence_high = 0x01020304
	command.target_slot = 111
	command.target_generation = 222
	command.goal_x = 333
	command.goal_z = 444
	command.arg0 = 555
	command.arg1 = 666
	command.payload_offset = 777
	command.payload_length = 888
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(Commands.RECORD_BYTES)
	assert_true(Commands.encode_command_into(command, bytes, 0), "the record encodes")
	assert_equal(bytes.decode_s64(0), 0x1122334455667788, "execute_tick i64 at offset 0")
	assert_equal(bytes.decode_s32(8), 9, "player_id i32 at offset 8")
	assert_equal(bytes.decode_u32(12), 0x0a0b0c0d, "sequence_low u32 bits at offset 12")
	assert_equal(bytes.decode_u32(16), 0x01020304, "sequence_high u32 bits at offset 16")
	_assert_tail_offsets(bytes, command)


func _assert_tail_offsets(bytes: PackedByteArray, command: Commands.Command) -> void:
	"""§8.1's offsets 20 through 60, split out only to keep one function under thirty lines."""
	assert_equal(bytes.decode_s32(20), _kind("UPGRADE"), "kind i32 at offset 20")
	assert_equal(bytes.decode_s32(24), 111, "target_slot i32 at offset 24")
	assert_equal(bytes.decode_s32(28), 222, "target_generation i32 at offset 28")
	assert_equal(bytes.decode_s32(32), 333, "goal_x i32 at offset 32")
	assert_equal(bytes.decode_s32(36), 444, "goal_z i32 at offset 36")
	assert_equal(bytes.decode_s32(40), 555, "arg0 i32 at offset 40")
	assert_equal(bytes.decode_s32(44), 666, "arg1 i32 at offset 44")
	assert_equal(bytes.decode_s32(48), 777, "payload_offset i32 at offset 48")
	assert_equal(bytes.decode_s32(52), 888, "payload_length i32 at offset 52")
	assert_equal(bytes.decode_s32(56), 12345, "flags i32 at offset 56")
	assert_equal(bytes.decode_s32(60), 0, "reserved_zero i32 at offset 60")
	assert_equal(bytes.size(), 64, "§8.1's stride is 64 bytes")
	assert_equal(command.kind, _kind("UPGRADE"), "the encoder did not mutate the record")


func test_every_intent_field_round_trips_through_the_queue() -> void:
	"""What comes out of the queue is what went in: every field `_write_row()` copies."""
	var ref: Vector2i = _live_ref()
	var command: Commands.Command = _command("SET_FIELD_ROTATION", 4321)
	command.target_slot = ref.x
	command.target_generation = ref.y
	command.goal_x = -12345
	command.goal_z = 67890
	command.arg1 = -777
	assert_true(_queue.submit_into(command, _result), "the command is accepted (%s)"
		% _result.error)
	assert_true(_queue.read_into(0, _read), "and it is queued")
	assert_equal(_read.kind, _kind("SET_FIELD_ROTATION"), "the kind is the one submitted")
	assert_equal(_read.target_slot, ref.x, "the target slot survives")
	assert_equal(_read.target_generation, ref.y, "the target generation survives")
	assert_equal(_read.goal_x, -12345, "goal_x survives, sign included")
	assert_equal(_read.goal_z, 67890, "goal_z survives")
	assert_equal(_read.arg0, 4321, "arg0 survives")
	assert_equal(_read.arg1, -777, "arg1 survives")
	assert_equal(_read.player_id, 0, "the stamped player is release 1's")
	assert_equal(_read.flags, 0, "flags is zero")
	assert_equal(_read.reserved_zero, 0, "and so is the reserved field")
	assert_true(_queue.drain_due_into(1, _read), "the drained record is the same record")
	assert_equal(_read.kind, _kind("SET_FIELD_ROTATION"), "with the same kind")
	assert_equal(_read.arg1, -777, "and the same arg1")


func test_the_stride_is_sixty_four_bytes_and_the_queue_holds_four_thousand_and_ninety_six() -> void:
	"""§2.3's ledger row is these two numbers: 4096 records of 64 bytes is 262144."""
	assert_equal(Commands.RECORD_BYTES, 64, "§8.1's [DERIVED sum] stride")
	assert_equal(Commands.QUEUE_CAPACITY, 4096, "§8.1's in-memory queue length")
	assert_equal(Commands.PAYLOAD_ARENA_BYTES, 1048576, "§8.1's payload arena")
	assert_equal(Commands.QUEUE_CAPACITY * Commands.RECORD_BYTES, 262144,
		"the ledger's Command queue row")
	assert_equal(_queue.capacity(), 4096, "the store reports the same capacity")


func test_a_record_round_trips_through_its_own_bytes() -> void:
	"""decode(encode(x)) is x, including a sequence word whose top bit is set."""
	var command: Commands.Command = _command("NAME_RESIDENT", 4242)
	command.execute_tick = 30001
	command.sequence_low = Commands.to_int32_bits(0x80000001)
	command.sequence_high = Commands.to_int32_bits(0xfffffffe)
	command.goal_x = -2147483648
	command.goal_z = 2147483647
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(Commands.RECORD_BYTES * 2)
	assert_true(Commands.encode_command_into(command, bytes, Commands.RECORD_BYTES),
		"a record encodes at a nonzero offset")
	assert_true(Commands.decode_record_into(bytes, Commands.RECORD_BYTES, _read), "it decodes")
	assert_equal(_read.execute_tick, 30001, "the tick survives")
	assert_equal(_read.sequence_low_unsigned(), 0x80000001, "the low word survives unsigned")
	assert_equal(_read.sequence_high_unsigned(), 0xfffffffe, "the high word survives unsigned")
	assert_equal(_read.goal_x, -2147483648, "the most negative i32 survives")
	assert_equal(_read.goal_z, 2147483647, "the most positive i32 survives")
	assert_equal(_read.arg0, 4242, "arg0 survives")
	assert_false(Commands.decode_record_into(bytes, Commands.RECORD_BYTES + 1, _read),
		"a record that runs off the end of the buffer refuses")
	assert_false(Commands.encode_command_into(command, bytes, -1), "a negative offset refuses")


# --- ARCH-CMD-003's compiled kind domain -------------------------------------------------------------

func test_all_twenty_four_kinds_compile_to_their_ascii_order() -> void:
	"""ARCH-CMD-003's exact list, in the exact order, each carrying its own index."""
	assert_equal(ARCH_CMD_003_KINDS.size(), 24, "ARCH-CMD-003 names twenty-four kinds")
	assert_equal(_queue.kind_count(), 24, "the queue compiles twenty-four of them")
	var sorted_keys: Array[String] = ARCH_CMD_003_KINDS.duplicate()
	sorted_keys.sort()
	for index: int in ARCH_CMD_003_KINDS.size():
		assert_equal(sorted_keys[index], ARCH_CMD_003_KINDS[index],
			"the printed list is already ASCII-sorted at index %d" % index)
		assert_equal(_kind(ARCH_CMD_003_KINDS[index]), index,
			"%s compiles to %d" % [ARCH_CMD_003_KINDS[index], index])


func test_the_kind_domain_is_the_ascii_compilation_of_its_own_keys() -> void:
	"""verify_compiled_enum() proves the table is generated, not hand-numbered."""
	var verified: CatalogScript.DomainResult = CatalogScript.verify_compiled_enum("CommandKind")
	assert_true(verified.ok, "CommandKind verifies (%s)" % verified.error)
	assert_equal(verified.ids.size(), 24, "all twenty-four ids are generated")
	assert_true(CatalogScript.COMPILED_ENUM_DOMAINS.has("CommandKind"), "it is registered")
	assert_false(CatalogScript.PROTECTED_ENUM_DOMAINS.has("CommandKind"),
		"§4.3 numbers none of these, so it is not protected")


func test_an_unknown_kind_is_refused_and_queues_nothing() -> void:
	"""ARCH-CMD-003: "reject unknown kinds"; there is no 24th, no -1 and no far value."""
	for kind: int in [24, -1, 1000000, -2147483648]:
		var command: Commands.Command = _command("EQUIP", 1)
		command.kind = kind
		assert_false(_queue.submit_into(command, _result), "kind %d is refused" % kind)
		assert_equal(_result.error, Commands.REFUSE_UNKNOWN_KIND, "with the unknown-kind code")
	assert_equal(_queue.pending_count(), 0, "a refused kind queues nothing")
	assert_true(_queue.is_valid_kind(0), "id 0 is a kind")
	assert_true(_queue.is_valid_kind(23), "id 23 is a kind")
	assert_false(_queue.is_valid_kind(24), "id 24 is not")


# --- ARCH-CMD-001's ordering key ---------------------------------------------------------------------

func test_sequence_order_is_unsigned_across_the_sign_bit() -> void:
	"""The signed-comparison defect, caught by value: 0x7fffffff must drain before 0x80000000.

	Stored as i32 those are 2147483647 and -2147483648, so a signed compare reverses them.
	"""
	assert_true(_queue.restore_sequence(0, 0x7fffffff), "resume at the last positive sequence")
	assert_true(_submit("SET_POLICY", 100), "the 0x7fffffff command is accepted")
	assert_true(_submit("SET_POLICY", 200), "the 0x80000000 command is accepted")
	assert_true(_queue.read_into(0, _read), "the queue has a head")
	assert_equal(_read.sequence_low_unsigned(), 0x7fffffff, "the head carries 0x7fffffff")
	assert_equal(_read.arg0, 100, "the head is the command issued first")
	assert_true(_queue.read_into(1, _read), "the queue has a second entry")
	assert_equal(_read.sequence_low_unsigned(), 0x80000000, "the second carries 0x80000000")
	assert_equal(_read.sequence_low, -2147483648, "which is negative in the i32 column")
	assert_equal(_read.arg0, 200, "and it is the command issued second")
	assert_true(_queue.drain_due_into(1, _read), "the first drains")
	assert_equal(_read.arg0, 100, "first out is the one issued first")
	assert_true(_queue.drain_due_into(1, _read), "the second drains")
	assert_equal(_read.arg0, 200, "second out is the one issued second")


func test_compare_key_parts_orders_by_tick_then_player_then_high_then_low() -> void:
	"""The whole key, term by term, including both unsigned words."""
	assert_equal(Commands.compare_key_parts(1, 0, 0, 0, 2, 0, 0, 0), -1, "a lower tick sorts first")
	assert_equal(Commands.compare_key_parts(2, 0, 9, 9, 1, 0, 0, 0), 1, "a higher tick sorts last")
	assert_equal(Commands.compare_key_parts(1, 0, 5, 5, 1, 1, 0, 0), -1, "player breaks a tie")
	assert_equal(Commands.compare_key_parts(1, 1, 0, 0, 1, 0, 9, 9), 1, "and it outranks sequence")
	assert_equal(Commands.compare_key_parts(1, 0, 1, 0, 1, 0, 2, 0), -1, "the high word is next")
	assert_equal(Commands.compare_key_parts(1, 0, 2, 0, 1, 0, 1, 999), 1, "and outranks the low")
	assert_equal(Commands.compare_key_parts(1, 0, 0, 1, 1, 0, 0, 2), -1, "the low word is last")
	assert_equal(Commands.compare_key_parts(7, 0, 3, 4, 7, 0, 3, 4), 0, "equal keys compare equal")
	var negative: int = Commands.to_int32_bits(0x80000000)
	assert_equal(Commands.compare_key_parts(1, 0, 0, 0x7fffffff, 1, 0, 0, negative), -1,
		"0x7fffffff precedes 0x80000000 in the low word")
	assert_equal(Commands.compare_key_parts(1, 0, 0x7fffffff, 0, 1, 0, negative, 0), -1,
		"0x7fffffff precedes 0x80000000 in the high word")
	assert_equal(Commands.compare_key_parts(1, 0, negative, 0, 1, 0, 0xffffffff, 0), -1,
		"0x80000000 still precedes 0xffffffff")


func test_permuted_arrival_produces_the_canonical_order() -> void:
	"""Stamped records arriving in any order are stored at their ARCH-CMD-001 position."""
	for sequence: int in [4, 1, 3, 0, 2]:
		var command: Commands.Command = _command("CANCEL_JOB", 10 + sequence)
		command.execute_tick = 1
		command.sequence_low = sequence
		assert_true(_queue.admit_stamped_into(command, _result),
			"sequence %d is admitted (%s)" % [sequence, _result.error])
	assert_equal(_queue.pending_count(), 5, "all five are queued")
	for position: int in 5:
		assert_equal(_arg0_at(position), 10 + position,
			"position %d holds the command with sequence %d" % [position, position])


func test_a_repeated_ordering_key_is_refused() -> void:
	"""Two records cannot share a key, or the order would not be a total one."""
	var first: Commands.Command = _command("DEMOLISH", 1)
	first.execute_tick = 1
	first.sequence_low = 0
	assert_true(_queue.admit_stamped_into(first, _result), "the first is admitted")
	var second: Commands.Command = _command("DEMOLISH", 2)
	second.execute_tick = 1
	second.sequence_low = 0
	assert_false(_queue.admit_stamped_into(second, _result), "the repeat is refused")
	assert_equal(_result.error, Commands.REFUSE_DUPLICATE_KEY, "with the duplicate-key code")
	assert_false(_submit("DEMOLISH", 3),
		"and the next stamped edit collides with the admitted record")
	assert_equal(_result.error, Commands.REFUSE_DUPLICATE_KEY, "for the same reason")
	assert_equal(_queue.pending_count(), 1, "only the first record is queued")
	assert_equal(_arg0_at(0), 1, "and it is the first one")


func test_a_stamped_record_due_at_a_completed_tick_is_refused() -> void:
	"""A late record refuses instead of executing at the wrong tick."""
	_run_one_tick()
	assert_true(_clock.completed_tick() >= 1, "a tick completed")
	var command: Commands.Command = _command("EDIT_ORDER", 1)
	command.execute_tick = _clock.completed_tick()
	assert_false(_queue.admit_stamped_into(command, _result), "the past tick is refused")
	assert_equal(_result.error, Commands.REFUSE_TICK_IN_PAST, "with the past-tick code")
	command.execute_tick = _clock.completed_tick() + 1
	assert_true(_queue.admit_stamped_into(command, _result), "the next tick is admitted")
	assert_equal(_queue.pending_count(), 1, "exactly one record is queued")


func test_a_foreign_player_id_is_refused() -> void:
	"""ARCH-CMD-001: "Player ID is 0 in release 1". Anything else refuses, never remaps."""
	var command: Commands.Command = _command("ASSIGN_BED", 1)
	command.execute_tick = 1
	command.player_id = 1
	assert_false(_queue.admit_stamped_into(command, _result), "player 1 is refused")
	assert_equal(_result.error, Commands.REFUSE_UNKNOWN_PLAYER, "with the unknown-player code")
	assert_equal(_queue.pending_count(), 0, "and nothing is queued")


# --- execute_tick = completed_tick + 1 ----------------------------------------------------------------

func test_a_submitted_command_is_due_at_the_next_tick() -> void:
	"""ARCH-CMD-001: "Assign each submitted command execute_tick=completed_tick+1"."""
	assert_equal(_clock.completed_tick(), 0, "a new world has completed no tick")
	assert_equal(_queue.next_execute_tick(), 1, "so the next tick is 1")
	assert_true(_submit("SET_DOOR_OPEN", 1), "the edit is accepted")
	assert_true(_queue.read_into(0, _read), "it is queued")
	assert_equal(_read.execute_tick, 1, "due at tick 1")
	assert_true(_queue.drain_due_into(1, _read), "and it drains at tick 1")
	_run_one_tick()
	var completed: int = _clock.completed_tick()
	assert_true(_submit("SET_DOOR_OPEN", 2), "a later edit is accepted")
	assert_true(_queue.read_into(0, _read), "it is queued")
	assert_equal(_read.execute_tick, completed + 1, "due at completed_tick + 1")
	assert_false(_queue.drain_due_into(completed, _read), "and nothing is due at the completed one")


func test_paused_edits_share_one_tick_with_increasing_sequences() -> void:
	"""ARCH-CMD-001: "paused edits receive the same next tick, increasing sequence"."""
	assert_true(_clock.is_paused(), "a new world starts paused")
	for index: int in 5:
		if not _submit("SET_POLICY", index):
			fail("paused edit %d should be accepted (%s)" % [index, _result.error])
			return
	assert_equal(_queue.pending_count(), 5, "all five are pending")
	for position: int in 5:
		assert_true(_queue.read_into(position, _read), "position %d reads" % position)
		assert_equal(_read.execute_tick, 1, "every paused edit is due at the same next tick")
		assert_equal(_read.sequence_low_unsigned(), position, "with an increasing sequence")
		assert_equal(_read.arg0, position, "and they keep the order they were issued in")


func test_pending_commands_survive_a_pause_without_being_consumed() -> void:
	"""ARCH-CMD-001: "Save pending commands when paused without consuming them"."""
	for index: int in 3:
		assert_true(_submit("SET_STORE_MINIMUM", index), "edit %d is accepted" % index)
	var before: PackedByteArray = _snapshot()
	assert_true(_clock.is_paused(), "the world is paused")
	for frame: int in 20:
		assert_equal(_clock.advance(33334), 0, "no tick runs while paused")
	assert_equal(_clock.completed_tick(), 0, "the completed tick did not move")
	assert_equal(_queue.pending_count(), 3, "and nothing was consumed")
	assert_equal(_queue.drained_count(), 0, "nothing was drained")
	assert_equal(_snapshot(), before, "the queued records are byte-identical")
	_run_one_tick()
	assert_equal(_queue.pending_count(), 3, "running a tick does not drain by itself either")
	var drained: int = 0
	while drained <= 3 and _queue.drain_due_into(_clock.completed_tick(), _read):
		drained += 1
	assert_equal(drained, 3, "and the tick's own drain finds all three")
	assert_false(_queue.drain_due_into(_clock.completed_tick(), _read),
		"after which an empty queue drains nothing")


# --- group atomicity ----------------------------------------------------------------------------------

func test_a_group_with_one_invalid_member_commits_none_of_it() -> void:
	"""ARCH-CMD-003: "all IDs must validate before committing any member of a group"."""
	assert_true(_submit("UPGRADE", 900), "one command is queued beforehand")
	var before: PackedByteArray = _snapshot()
	var sequence_before: int = _queue.next_sequence_low()
	var group: Array = [_command("SET_POLICY", 1), _command("SET_POLICY", 2),
		_command("SET_POLICY", 3)]
	var bad: Commands.Command = group[2] as Commands.Command
	bad.target_slot = 5
	bad.target_generation = 99
	assert_false(_queue.submit_group_into(group, _result), "the group is refused")
	assert_equal(_result.error, Commands.REFUSE_TARGET_INVALID, "for the stale target")
	assert_equal(_result.member, 2, "and it names the member that failed")
	assert_equal(_result.accepted, 0, "nothing was accepted")
	assert_equal(_queue.pending_count(), 1, "no member reached the queue")
	assert_equal(_snapshot(), before, "the queue is byte-identical")
	assert_equal(_queue.next_sequence_low(), sequence_before, "no sequence number was consumed")
	assert_equal(_queue.payload_used(), 0, "no arena byte was consumed")


func test_a_valid_group_commits_every_member_in_order() -> void:
	"""The other half of atomicity: all or nothing means ALL when every member validates."""
	var group: Array = [_command("CANCEL_MANUAL", 11), _command("CANCEL_MANUAL", 22),
		_command("CANCEL_MANUAL", 33)]
	assert_true(_queue.submit_group_into(group, _result), "the group is accepted (%s)"
		% _result.error)
	assert_equal(_result.accepted, 3, "all three members are accepted")
	assert_equal(_queue.pending_count(), 3, "and all three are queued")
	for position: int in 3:
		assert_true(_queue.read_into(position, _read), "position %d reads" % position)
		assert_equal(_read.arg0, 11 * (position + 1), "members keep their submitted order")
		assert_equal(_read.execute_tick, 1, "they share one execute tick")
		assert_equal(_read.sequence_low_unsigned(), position, "with consecutive sequences")


func test_a_single_refusal_never_reports_a_previous_group_member() -> void:
	"""`SubmitResult.member` is cleared on entry, so a stale group index cannot be reported."""
	var group: Array = [_command("EQUIP", 1), _command("EQUIP", 2)]
	var bad: Commands.Command = group[1] as Commands.Command
	bad.reserved_zero = 3
	assert_false(_queue.submit_group_into(group, _result), "the group is refused")
	assert_equal(_result.member, 1, "naming member 1")
	var single: Commands.Command = _command("EQUIP", 3)
	single.flags = 8
	assert_false(_queue.submit_into(single, _result), "a later single command is refused")
	assert_equal(_result.error, Commands.REFUSE_FLAGS_UNDEFINED, "for its own reason")
	assert_equal(_result.member, 0, "and it reports no group member")


func test_an_id_group_refuses_an_envelope_that_also_carries_payload_bytes() -> void:
	"""The ID-group form builds the payload, so opaque bytes are refused, never dropped."""
	var ref: Vector2i = _live_ref()
	var command: Commands.Command = _command("SET_JOB_PRIORITIES", 1)
	command.payload = PackedByteArray([1, 2, 3])
	var refs: PackedInt32Array = PackedInt32Array([ref.x, ref.y])
	assert_false(_queue.submit_id_group_into(command, refs, _result), "the conflict is refused")
	assert_equal(_result.error, Commands.REFUSE_PAYLOAD_CONFLICT, "with the conflict code")
	assert_equal(_queue.pending_count(), 0, "and nothing is queued")
	command.payload = PackedByteArray()
	assert_true(_queue.submit_id_group_into(command, refs, _result),
		"an envelope with no opaque bytes is accepted (%s)" % _result.error)
	assert_true(_queue.read_into(0, _read), "it is queued")
	assert_equal(_read.payload_length, 12, "carrying only the built ID group")


func test_compare_keys_reads_a_whole_record_through_the_same_comparison() -> void:
	"""The record-level comparator delegates, so a save or replay validator cannot disagree."""
	var first: Commands.Command = _command("UPGRADE", 1)
	first.execute_tick = 5
	first.sequence_low = 0x7fffffff
	var second: Commands.Command = _command("UPGRADE", 2)
	second.execute_tick = 5
	second.sequence_low = Commands.to_int32_bits(0x80000000)
	assert_equal(Commands.compare_keys(first, second), -1, "0x7fffffff precedes 0x80000000")
	assert_equal(Commands.compare_keys(second, first), 1, "and the reverse holds")
	assert_equal(Commands.compare_keys(first, first), 0, "a record equals itself")
	second.execute_tick = 4
	assert_equal(Commands.compare_keys(first, second), 1, "an earlier tick still wins")


func test_a_reset_envelope_is_the_empty_one() -> void:
	"""One owned Command can be reused for a second submission without carrying the first."""
	var command: Commands.Command = _command("NAME_RESIDENT", 77)
	command.payload = PackedByteArray([9])
	command.goal_x = 5
	assert_true(_queue.submit_into(command, _result), "the first submission is accepted")
	command.reset()
	assert_equal(command.kind, 0, "the kind clears")
	assert_equal(command.arg0, 0, "the arg clears")
	assert_equal(command.goal_x, 0, "the goal clears")
	assert_equal(command.target_slot, -1, "the target returns to the null slot")
	assert_equal(command.payload.size(), 0, "and the payload empties")
	assert_true(_queue.submit_into(command, _result), "a reset envelope is still valid (%s)"
		% _result.error)
	assert_equal(_arg0_at(1), 0, "and it queues the empty command, not the first one")


func test_an_empty_or_mistyped_group_is_refused() -> void:
	"""A group of nothing is not a group, and a non-command member is not a member."""
	assert_false(_queue.submit_group_into([], _result), "an empty group is refused")
	assert_equal(_result.error, Commands.REFUSE_EMPTY_GROUP, "with the empty-group code")
	assert_false(_queue.submit_group_into([_command("EQUIP", 1), 17], _result),
		"a group holding a non-command is refused")
	assert_equal(_result.error, Commands.REFUSE_GROUP_MEMBER_TYPE, "with the member-type code")
	assert_equal(_result.member, 1, "naming the member that is not a command")
	assert_equal(_queue.pending_count(), 0, "and nothing is queued")


func test_an_id_group_validates_every_reference_before_writing_one() -> void:
	"""ARCH-CMD-003's count-prefixed, owner-ID-sorted rows: one stale generation refuses all."""
	var first: Vector2i = _live_ref()
	var second: Vector2i = _live_ref()
	var refs: PackedInt32Array = PackedInt32Array([first.x, first.y, second.x, second.y])
	var before: PackedByteArray = _snapshot()
	var stale: PackedInt32Array = PackedInt32Array([first.x, first.y, second.x, second.y + 1])
	assert_false(_queue.submit_id_group_into(_command("SET_JOB_PRIORITIES", 1), stale, _result),
		"a stale generation refuses the whole group")
	assert_equal(_result.error, Commands.REFUSE_ID_GROUP_MEMBER, "with the member code")
	assert_equal(_queue.pending_count(), 0, "and nothing is queued")
	assert_equal(_snapshot(), before, "the queue is byte-identical")
	assert_equal(_queue.payload_used(), 0, "and no arena byte was consumed")
	assert_true(_queue.submit_id_group_into(_command("SET_JOB_PRIORITIES", 1), refs, _result),
		"the valid group is accepted (%s)" % _result.error)
	_assert_id_group_payload(first, second)


func _assert_id_group_payload(first: Vector2i, second: Vector2i) -> void:
	"""The committed payload is a count followed by the owner-ID-sorted EntityRef rows."""
	assert_true(_queue.read_into(0, _read), "the command is queued")
	assert_equal(_read.payload_offset, 0, "its payload starts at the arena's base")
	assert_equal(_read.payload_length, 20, "4 count bytes plus two 8-byte rows")
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(_read.payload_length)
	assert_true(_queue.read_payload_into(_read, bytes), "the payload reads back")
	assert_equal(bytes.decode_s32(0), 2, "the count comes first")
	assert_equal(bytes.decode_s32(4), first.x, "then the first slot")
	assert_equal(bytes.decode_s32(8), first.y, "and its generation")
	assert_equal(bytes.decode_s32(12), second.x, "then the second slot")
	assert_equal(bytes.decode_s32(16), second.y, "and its generation")


func test_an_id_group_refuses_an_unsorted_or_malformed_list() -> void:
	"""Owner-ID order is refused into existence, never silently produced."""
	var first: Vector2i = _live_ref()
	var second: Vector2i = _live_ref()
	var unsorted: PackedInt32Array = PackedInt32Array([second.x, second.y, first.x, first.y])
	assert_false(_queue.submit_id_group_into(_command("ACCEPT_CANDIDATES", 1), unsorted, _result),
		"descending owner ids are refused")
	assert_equal(_result.error, Commands.REFUSE_ID_GROUP_UNSORTED, "with the unsorted code")
	var repeated: PackedInt32Array = PackedInt32Array([first.x, first.y, first.x, first.y])
	assert_false(_queue.submit_id_group_into(_command("ACCEPT_CANDIDATES", 1), repeated, _result),
		"a repeated owner id is refused")
	assert_equal(_result.error, Commands.REFUSE_ID_GROUP_UNSORTED, "for the same reason")
	var odd: PackedInt32Array = PackedInt32Array([first.x, first.y, second.x])
	assert_false(_queue.submit_id_group_into(_command("ACCEPT_CANDIDATES", 1), odd, _result),
		"a half row is refused")
	assert_equal(_result.error, Commands.REFUSE_ID_GROUP_SHAPE, "with the shape code")
	assert_false(_queue.submit_id_group_into(_command("ACCEPT_CANDIDATES", 1),
		PackedInt32Array(), _result), "an empty list is refused")
	assert_equal(_queue.pending_count(), 0, "and nothing is queued")


# --- envelope validation --------------------------------------------------------------------------------

func test_reserved_zero_must_be_zero() -> void:
	"""§8.1 names offset 60 `reserved_zero`; a nonzero value refuses and is never stored."""
	var command: Commands.Command = _command("CONFIRM_FEAST", 1)
	command.reserved_zero = 1
	assert_false(_queue.submit_into(command, _result), "a nonzero reserved field refuses")
	assert_equal(_result.error, Commands.REFUSE_RESERVED_NONZERO, "with the reserved code")
	assert_equal(_queue.pending_count(), 0, "and nothing is queued")
	command.reserved_zero = -1
	assert_false(_queue.submit_into(command, _result), "a negative reserved field also refuses")
	command.reserved_zero = 0
	assert_true(_queue.submit_into(command, _result), "zero is accepted")
	assert_true(_queue.read_into(0, _read), "the command is queued")
	assert_equal(_read.reserved_zero, 0, "and the stored field is zero")


func test_an_undefined_flag_bit_is_refused() -> void:
	"""No specification defines a bit in `flags`, so a nonzero value is refused, not stored."""
	var command: Commands.Command = _command("PLACE_BLUEPRINT", 1)
	command.flags = 1
	assert_false(_queue.submit_into(command, _result), "flag bit 0 refuses")
	assert_equal(_result.error, Commands.REFUSE_FLAGS_UNDEFINED, "with the undefined-flags code")
	assert_equal(_queue.pending_count(), 0, "and nothing is queued")


func test_a_target_is_generation_checked_against_the_directory() -> void:
	"""ARCH-ID-003: a reused slot with an old generation is not the entity that was targeted."""
	var ref: Vector2i = _live_ref()
	var command: Commands.Command = _command("ASSIGN_BED", 1)
	command.target_slot = ref.x
	command.target_generation = ref.y
	assert_true(_queue.submit_into(command, _result), "a live target is accepted (%s)"
		% _result.error)
	assert_true(_directory.destroy(ref), "the target is destroyed")
	var stale: Commands.Command = _command("ASSIGN_BED", 2)
	stale.target_slot = ref.x
	stale.target_generation = ref.y
	assert_false(_queue.submit_into(stale, _result), "the stale reference is refused")
	assert_equal(_result.error, Commands.REFUSE_TARGET_INVALID, "with the invalid-target code")
	var malformed: Commands.Command = _command("ASSIGN_BED", 3)
	malformed.target_slot = -1
	malformed.target_generation = 4
	assert_false(_queue.submit_into(malformed, _result), "a malformed null reference is refused")
	assert_equal(_result.error, Commands.REFUSE_TARGET_MALFORMED, "with the malformed code")
	assert_equal(_queue.pending_count(), 1, "only the live-target command is queued")


func test_the_null_reference_is_a_legal_absent_target() -> void:
	"""`(-1, 0)` means "this command names no entity", which most kinds do not."""
	var command: Commands.Command = _command("REQUEST_RELIEF_SEEDS", 1)
	assert_equal(command.target_slot, -1, "a fresh envelope carries the null slot")
	assert_equal(command.target_generation, 0, "and the null generation")
	assert_true(_queue.submit_into(command, _result), "and it is accepted (%s)" % _result.error)
	assert_true(_queue.read_into(0, _read), "it is queued")
	assert_equal(_read.target_ref(), Vector2i(-1, 0), "with the null reference intact")


func test_an_out_of_range_field_is_refused() -> void:
	"""Every i32 field is checked against the i32 range, not truncated into it."""
	var command: Commands.Command = _command("SET_STORE_FILTER", 1)
	command.goal_x = 2147483648
	assert_false(_queue.submit_into(command, _result), "goal_x above i32 refuses")
	assert_equal(_result.error, Commands.REFUSE_FIELD_RANGE, "with the field-range code")
	command.goal_x = 0
	command.arg1 = -2147483649
	assert_false(_queue.submit_into(command, _result), "arg1 below i32 refuses")
	assert_equal(_result.error, Commands.REFUSE_FIELD_RANGE, "for the same reason")
	assert_equal(_queue.pending_count(), 0, "and nothing is queued")


# --- capacity, payload and sequence exhaustion ----------------------------------------------------------

func test_the_four_thousand_and_ninety_seventh_command_refuses_cleanly() -> void:
	"""§8.1: "Queue overflow refuses additional edits ... accepted commands are never dropped"."""
	for index: int in Commands.QUEUE_CAPACITY:
		if not _submit("APPOINT_WARDEN", index):
			fail("command %d should have been accepted (%s)" % [index, _result.error])
			return
	assert_equal(_queue.pending_count(), 4096, "the queue is exactly full")
	assert_equal(_queue.free_count(), 0, "with no room left")
	assert_false(_submit("APPOINT_WARDEN", 4096), "the 4097th refuses")
	assert_equal(_result.error, Commands.REFUSE_QUEUE_FULL, "with the queue-full code")
	assert_equal(_queue.pending_count(), 4096, "and drops nothing that was accepted")
	assert_equal(_arg0_at(0), 0, "the first accepted command is still first")
	assert_equal(_arg0_at(4095), 4095, "and the last accepted one is still last")
	assert_true(_queue.drain_due_into(1, _read), "one drains")
	assert_equal(_read.arg0, 0, "in order")
	assert_true(_submit("APPOINT_WARDEN", 5000), "which makes room for exactly one more")
	assert_equal(_queue.pending_count(), 4096, "and the queue is full again")


func test_a_payload_larger_than_the_arena_refuses() -> void:
	"""The arena is 1048576 bytes and refuses rather than overwriting a pending command."""
	var command: Commands.Command = _command("SET_ACTIVITY_SCHEDULE", 1)
	command.payload.resize(Commands.PAYLOAD_ARENA_BYTES)
	assert_true(_queue.submit_into(command, _result), "a payload the size of the arena fits (%s)"
		% _result.error)
	assert_equal(_queue.payload_used(), Commands.PAYLOAD_ARENA_BYTES, "and fills it")
	assert_equal(_queue.payload_available(), 0, "leaving nothing")
	var second: Commands.Command = _command("SET_ACTIVITY_SCHEDULE", 2)
	second.payload.resize(1)
	assert_false(_queue.submit_into(second, _result), "one more byte refuses")
	assert_equal(_result.error, Commands.REFUSE_PAYLOAD_ARENA_FULL, "with the arena-full code")
	assert_equal(_queue.pending_count(), 1, "and nothing is queued")


func test_the_arena_is_reclaimed_only_when_the_queue_empties() -> void:
	"""Bump-and-reset: a drained queue returns the whole arena; a partly drained one does not."""
	var first: Commands.Command = _command("SET_ACTIVITY_SCHEDULE", 1)
	first.payload.resize(600000)
	assert_true(_queue.submit_into(first, _result), "the first payload fits (%s)" % _result.error)
	var second: Commands.Command = _command("SET_ACTIVITY_SCHEDULE", 2)
	second.payload.resize(400000)
	assert_true(_queue.submit_into(second, _result), "the second fits too (%s)" % _result.error)
	assert_equal(_queue.payload_used(), 1000000, "both are reserved")
	assert_true(_queue.drain_due_into(1, _read), "one drains")
	assert_equal(_queue.payload_used(), 1000000, "which reclaims nothing on its own")
	assert_true(_queue.drain_due_into(1, _read), "the last drains")
	assert_equal(_queue.pending_count(), 0, "emptying the queue")
	assert_equal(_queue.payload_used(), 0, "which returns the whole arena")
	assert_equal(_queue.payload_available(), Commands.PAYLOAD_ARENA_BYTES, "all of it")
	_assert_the_arena_really_restarts()


func _assert_the_arena_really_restarts() -> void:
	"""Reclamation is observed where it matters: the NEXT allocation starts at offset 0 again.

	`payload_used()` reporting zero is not enough -- it reports zero whenever the queue is empty,
	so a bump cursor that was never reset would look identical until the next payload ran off the
	end of the arena.
	"""
	var third: Commands.Command = _command("SET_ACTIVITY_SCHEDULE", 3)
	third.payload = PackedByteArray([7, 7, 7])
	assert_true(_queue.submit_into(third, _result), "a later payload is accepted (%s)"
		% _result.error)
	assert_true(_queue.read_into(0, _read), "it is queued")
	assert_equal(_read.payload_offset, 0, "at the base of the arena, so the cursor restarted")
	assert_equal(_queue.payload_used(), 3, "using only its own three bytes")
	var out: PackedByteArray = PackedByteArray()
	out.resize(3)
	assert_true(_queue.read_payload_into(_read, out), "and its bytes read back")
	assert_equal(out, PackedByteArray([7, 7, 7]), "unchanged")


func test_a_payload_round_trips_through_the_arena() -> void:
	"""Opaque payload bytes come back exactly, at a validated span."""
	var command: Commands.Command = _command("SET_FIELD_ROTATION", 1)
	command.payload = PackedByteArray([3, 1, 4, 1, 5, 9, 2, 6])
	assert_true(_queue.submit_into(command, _result), "the command is accepted (%s)"
		% _result.error)
	assert_true(_queue.read_into(0, _read), "it is queued")
	assert_equal(_read.payload_offset, 0, "at the base of the arena")
	assert_equal(_read.payload_length, 8, "with its own length")
	var out: PackedByteArray = PackedByteArray()
	out.resize(8)
	assert_true(_queue.read_payload_into(_read, out), "the payload reads back")
	assert_equal(out, PackedByteArray([3, 1, 4, 1, 5, 9, 2, 6]), "byte for byte")
	var small: PackedByteArray = PackedByteArray()
	small.resize(7)
	assert_false(_queue.read_payload_into(_read, small), "a short buffer refuses")
	assert_equal(_queue.last_refusal(), Commands.REFUSE_BUFFER_TOO_SMALL, "with the buffer code")


func test_a_payload_span_outside_the_arena_is_refused() -> void:
	"""`payload_offset`/`payload_length` are validated fields, not trusted ones."""
	assert_equal(_queue.payload_span_refusal(0, 0), Commands.REFUSE_NONE, "an empty span is legal")
	assert_equal(_queue.payload_span_refusal(1048575, 1), Commands.REFUSE_NONE,
		"a span ending exactly at the arena's end is legal")
	assert_equal(_queue.payload_span_refusal(1048576, 1), Commands.REFUSE_PAYLOAD_SPAN,
		"one byte past it is not")
	assert_equal(_queue.payload_span_refusal(-1, 4), Commands.REFUSE_PAYLOAD_SPAN,
		"a negative offset is not")
	assert_equal(_queue.payload_span_refusal(0, -4), Commands.REFUSE_PAYLOAD_SPAN,
		"a negative length is not")
	assert_equal(_queue.payload_span_refusal(9223372036854775807, 1),
		Commands.REFUSE_PAYLOAD_SPAN, "and an overflowing sum refuses instead of wrapping")


func test_the_session_sequence_exhausts_instead_of_wrapping() -> void:
	"""04.2: "sequence-exhaustion refusal without wraparound"."""
	assert_true(_queue.restore_sequence(0xffffffff, 0xffffffff), "resume at the last sequence")
	assert_true(_submit("EQUIP", 1), "the last sequence number is usable (%s)" % _result.error)
	assert_true(_queue.read_into(0, _read), "and it is queued")
	assert_equal(_read.sequence_high_unsigned(), 0xffffffff, "with the top high word")
	assert_equal(_read.sequence_low_unsigned(), 0xffffffff, "and the top low word")
	assert_false(_submit("EQUIP", 2), "the next one refuses")
	assert_equal(_result.error, Commands.REFUSE_SEQUENCE_EXHAUSTED, "with the exhaustion code")
	assert_equal(_queue.pending_count(), 1, "and nothing more is queued")


func test_the_sequence_carries_into_the_high_word() -> void:
	"""The counter is 64 bits in two u32 halves, not two independent numbers."""
	assert_true(_queue.restore_sequence(7, 0xffffffff), "resume at the end of a low word")
	assert_true(_submit("EQUIP", 1), "the last of that word is accepted")
	assert_true(_submit("EQUIP", 2), "and the next carries")
	assert_true(_queue.read_into(1, _read), "the second command reads")
	assert_equal(_read.sequence_high_unsigned(), 8, "the high word advanced")
	assert_equal(_read.sequence_low_unsigned(), 0, "and the low word restarted")
	assert_equal(_arg0_at(0), 1, "and 0xffffffff still sorts before the carried value")


func test_restore_sequence_refuses_a_bad_word_or_a_busy_queue() -> void:
	"""The load path validates its input and will not mint a key into a live queue."""
	assert_false(_queue.restore_sequence(-1, 0), "a negative high word refuses")
	assert_equal(_queue.last_refusal(), Commands.REFUSE_SEQUENCE_RANGE, "with the range code")
	assert_false(_queue.restore_sequence(0, 4294967296), "a low word above u32 refuses")
	assert_true(_submit("UPGRADE", 1), "with one command queued")
	assert_false(_queue.restore_sequence(0, 0), "restoring refuses")
	assert_equal(_queue.last_refusal(), Commands.REFUSE_QUEUE_NOT_EMPTY, "with the not-empty code")
	assert_equal(_queue.next_sequence_low(), 1, "and the counter is untouched")


# --- queue mechanics ------------------------------------------------------------------------------------

func test_rows_are_never_handed_out_twice_across_churn() -> void:
	"""The order ring stays a permutation: 4096 distinct commands survive a wrap of the storage."""
	for index: int in 3000:
		if not _submit("DESIGNATE_ZONE", index) or not _queue.drain_due_into(1, _read):
			fail("warm-up %d should submit and drain (%s)" % [index, _result.error])
			return
	assert_equal(_queue.pending_count(), 0, "the queue is empty after the warm-up")
	for index: int in Commands.QUEUE_CAPACITY:
		if not _submit("DESIGNATE_ZONE", 1000000 + index):
			fail("command %d should have been accepted (%s)" % [index, _result.error])
			return
	var seen: Dictionary = {}
	for position: int in Commands.QUEUE_CAPACITY:
		if not _queue.read_into(position, _read):
			fail("position %d should read" % position)
			return
		if seen.has(_read.arg0):
			fail("two positions hold the same command %d" % _read.arg0)
			return
		seen[_read.arg0] = position
	assert_equal(seen.size(), Commands.QUEUE_CAPACITY, "every queued command is distinct")
	assert_equal(_arg0_at(0), 1000000, "and the head is still the first one submitted")


func test_reading_outside_the_queue_refuses() -> void:
	"""There is no position -1 and no position past the end; neither returns a plausible record."""
	assert_false(_queue.drain_due_into(1, _read), "an empty queue drains nothing")
	assert_equal(_queue.pending_count(), 0, "and its count cannot go negative")
	assert_equal(_queue.drained_count(), 0, "nor can it count a drain that did not happen")
	assert_false(_queue.read_into(0, _read), "an empty queue has no head")
	assert_equal(_queue.last_refusal(), Commands.REFUSE_POSITION, "with the position code")
	assert_true(_submit("DEMOLISH", 5), "one command is queued")
	assert_false(_queue.read_into(-1, _read), "position -1 refuses")
	assert_false(_queue.read_into(1, _read), "position 1 refuses")
	assert_true(_queue.peek_into(_read), "but the head reads")
	assert_equal(_read.arg0, 5, "and it is the queued command")
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(Commands.RECORD_BYTES)
	assert_false(_queue.encode_record_into(1, bytes, 0), "encoding a missing position refuses")
	assert_false(_queue.encode_record_into(0, bytes, 1), "as does a buffer that is too short")


func test_only_due_commands_drain() -> void:
	"""A command queued for a later tick is not handed to an earlier one."""
	var early: Commands.Command = _command("CANCEL_JOB", 1)
	early.execute_tick = 1
	assert_true(_queue.admit_stamped_into(early, _result), "the tick-1 command is admitted")
	var late: Commands.Command = _command("CANCEL_JOB", 2)
	late.execute_tick = 9
	late.sequence_low = 1
	assert_true(_queue.admit_stamped_into(late, _result), "the tick-9 command is admitted")
	assert_equal(_queue.due_count(1), 1, "one is due at tick 1")
	assert_equal(_queue.due_count(8), 1, "still one at tick 8")
	assert_equal(_queue.due_count(9), 2, "both at tick 9")
	assert_true(_queue.drain_due_into(1, _read), "the due one drains")
	assert_equal(_read.arg0, 1, "and it is the tick-1 command")
	assert_false(_queue.drain_due_into(1, _read), "the later one does not")
	assert_equal(_queue.pending_count(), 1, "and stays queued")
	assert_true(_queue.drain_due_into(9, _read), "until its own tick")
	assert_equal(_read.arg0, 2, "when it drains")


func test_clear_returns_the_queue_to_its_initial_state() -> void:
	"""World initialization: pending commands, the arena and the session sequence all reset."""
	for index: int in 4:
		assert_true(_submit("SET_MANUAL_TASK", index), "edit %d is accepted" % index)
	_queue.clear()
	assert_equal(_queue.pending_count(), 0, "no command is pending")
	assert_equal(_queue.payload_used(), 0, "the arena is empty")
	assert_equal(_queue.next_sequence_low(), 0, "the sequence restarts")
	assert_equal(_queue.next_sequence_high(), 0, "in both words")
	assert_equal(_queue.accepted_count(), 0, "and the counters restart")
	assert_true(_submit("SET_MANUAL_TASK", 99), "a fresh command is accepted")
	assert_equal(_arg0_at(0), 99, "and it is the only one")


func test_the_counters_report_admissions_refusals_and_drains() -> void:
	"""The diagnostics a UI error message is built from."""
	assert_true(_submit("SET_POLICY", 1), "one accepted")
	var bad: Commands.Command = _command("SET_POLICY", 2)
	bad.kind = 999
	assert_false(_queue.submit_into(bad, _result), "one refused")
	assert_true(_queue.drain_due_into(1, _read), "one drained")
	assert_equal(_queue.accepted_count(), 1, "one acceptance")
	assert_equal(_queue.refused_count(), 1, "one refusal")
	assert_equal(_queue.drained_count(), 1, "one drain")
	assert_equal(_queue.last_refusal(), Commands.REFUSE_UNKNOWN_KIND,
		"and the refusal code is retained for the UI to report")
	assert_true(_submit("SET_POLICY", 3), "a later acceptance")
	assert_equal(_queue.last_refusal(), Commands.REFUSE_NONE, "clears it")
	assert_equal(_queue.accepted_count(), 2, "and counts the second acceptance")


func test_the_queue_shares_the_clock_and_directory_it_was_given() -> void:
	"""One directory validates the targets, or two stores could disagree about a generation."""
	assert_true(_queue.clock() == _clock, "the clock is the one supplied")
	assert_true(_queue.directory() == _directory, "the directory is the one supplied")
	var private_queue: Commands = Commands.new()
	assert_not_null(private_queue.clock(), "a queue built with nothing owns a clock")
	assert_not_null(private_queue.directory(), "and a directory")
	assert_equal(private_queue.next_execute_tick(), 1, "whose completed tick starts at zero")
