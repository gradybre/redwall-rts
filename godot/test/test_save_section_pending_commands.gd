extends "res://test/framework/test_case.gd"
## Adversarial suite for ARCH-SAVE-002 section 12 PENDING_COMMANDS.
##
## Section 12 is the only section whose contents decide the ORDER future work happens in. A §3 that
## loads wrong corrupts identity; a §12 that loads wrong replays the player's edits in a different
## order, and every downstream difference looks like a legitimate divergence. Round-trip equality is
## therefore the floor, not the test. The cases that matter are the ones where a wrong load still
## looks entirely plausible:
##
##   * RING GARBAGE PERSISTED. Both queues are rings whose tail holds whatever a drained record
##     left. Two observationally identical worlds hold different garbage there, so persisting it
##     produces different bytes and different CRCs for the same world.
##   * HEAD AND COUNT ROUND-TRIPPED WRONG. A wrapped `_head` means queue position 0 is NOT row 0.
##     A capture that read rows instead of positions reorders the queue and nothing errors.
##   * A u32 SEQUENCE HALF READ AS A NEGATIVE i32. `0x80000000` is a POSITIVE 2147483648 in
##     GDScript and `-2147483648` is the same four bytes read as int32. Both queues keep u32 bits in
##     i32 columns, so a signed comparison puts 0x80000000 BEFORE 0x7fffffff.
##   * THE TWO OWNERS' BLOCKS OUT OF ORDER. `commands` precedes `scheduler_events` in ASCII and in
##     the bytes; the `SCHQ0001` tag sits at exactly `28 + 64*E + P` and nowhere else.
##   * COMMIT-THEN-VALIDATE. Every refusal case below is exercised with a FULL-LENGTH section, so a
##     decoder that wrote its output before validating would pass a truncation test and still lose
##     the caller's state.
##   * `payload_byte_length` DISAGREEING WITH THE BODY. Both the prefix's
##     `scheduler_extension_bytes` and the nested subsection's own length are checked against the
##     bytes actually present.
##
## THE OFFSET CALENDAR IS THE PAYLOAD, NOT A DECORATION. 30 ticks/second, 18000 ticks/day, the
## offset calendar `(tick + 4500) mod 18000` and first midnight at 13500. `tick % 18000 == 0` is
## 06:00, never midnight, so the boundary fixtures here save at completed tick 13499 and 17999 and
## carry commands due at 13500 and 18000.
##
## EVERY BOUNDARY VALUE IS BUILT THROUGH `SaveCodec.u32_bits_to_int32()` / `int32_bits_to_u32()`
## and the pair is asserted, rather than typing a signed literal and hoping -- a real bug has
## hidden inside the test written to catch it.

const SaveCodec := preload("res://scripts/core/save_codec.gd")
const SaveHeader := preload("res://scripts/core/save_header.gd")
const PendingCommands := preload("res://scripts/core/save_section_pending_commands.gd")
const CommandsScript := preload("res://scripts/core/commands.gd")
const SchedulerEventsScript := preload("res://scripts/core/scheduler_events.gd")
const SimClockScript := preload("res://scripts/core/sim_clock.gd")
const EntityDirectoryScript := preload("res://scripts/core/entity_directory.gd")
const CatalogScript := preload("res://scripts/core/catalog.gd")

## GDD §5.1's offset calendar. First midnight is 13500 and a day is 18000 ticks.
const FIRST_MIDNIGHT_TICK: int = 13500
const TICKS_PER_DAY: int = 18000

var _clock: SimClockScript = null
var _directory: EntityDirectoryScript = null
var _commands: CommandsScript = null
var _scheduler: SchedulerEventsScript = null


func before_each() -> void:
	"""Build one consistent clock/directory/queue world per test."""
	_clock = SimClockScript.new()
	_directory = EntityDirectoryScript.new()
	_commands = CommandsScript.new(_clock, _directory)
	_scheduler = SchedulerEventsScript.new(_clock)


# --- helpers -----------------------------------------------------------------------------------------

func _empty_section_hex() -> String:
	"""Schema 3 pinned bytes include the eight-byte economic high word."""
	return "0300000000000000000000003000000000000000000000000000000053434851" \
		+ "30303031010000002000000000000000000000000100000000000000ffffffff" \
		+ "ffffffff0000000000000000"


func _one_each_section_hex() -> String:
	"""Schema 3 pinned bytes include the eight-byte economic high word."""
	return "0300000001000000050000005000000001000000000000000000000001000000" \
		+ "0000000000000000000000000000000008000000ffffffff0000000000000000" \
		+ "0000000005000000000000000000000005000000000000000000000001020304" \
		+ "0553434851303030310100000040000000000000000100000002000000000000" \
		+ "00ffffffffffffffff0000000000000000000000000000000001000000000000" \
		+ "0000000000000000000200000000000000"


func _capture() -> PendingCommands.Record:
	"""Capture the fixture world, failing the test rather than returning a half-filled Record."""
	var record: PendingCommands.Record = PendingCommands.Record.new()
	var refusal: SaveHeader.Refusal = PendingCommands.capture_into(_commands, _scheduler, record)
	if not refusal.is_ok():
		fail("capture refused: %s %s" % [refusal.code, refusal.detail])
	return record


func _encode(record: PendingCommands.Record) -> PackedByteArray:
	"""Encode a Record, failing the test rather than returning empty bytes on a refusal."""
	var result: PendingCommands.EncodeResult = PendingCommands.EncodeResult.new()
	if not PendingCommands.encode_record(record, result):
		fail("encode refused: %s %s" % [result.refusal, result.detail])
	return result.bytes


func _encoded_world() -> PackedByteArray:
	"""Capture and encode the fixture world in one step."""
	return _encode(_capture())


func _submit(kind: int, arg0: int, payload: PackedByteArray) -> bool:
	"""Submit one economic command with an opaque payload. Returns the queue's verdict."""
	var command: CommandsScript.Command = CommandsScript.Command.new()
	command.kind = kind
	command.arg0 = arg0
	command.payload = payload
	var result: CommandsScript.SubmitResult = CommandsScript.SubmitResult.new()
	return _commands.submit_into(command, result)


func _submit_speed(value: int) -> bool:
	"""Submit one scheduler speed event. Returns the queue's verdict."""
	var result: SchedulerEventsScript.SubmitResult = SchedulerEventsScript.SubmitResult.new()
	return _scheduler.submit_speed_into(value, result)


func _set_completed_tick(tick: int) -> void:
	"""Install a completed tick through RESTORE-R01's assignment API, never by simulating."""
	assert_true(_clock.restore_runtime(tick, 0, 1, 0, 0, 0, 0, 0, 0, 0),
		"the clock must accept completed tick %d" % tick)


func _fresh_world() -> Array:
	"""A second empty clock/directory/queue world, for `apply()` to install into."""
	var clock: SimClockScript = SimClockScript.new()
	var directory: EntityDirectoryScript = EntityDirectoryScript.new()
	return [clock, directory, CommandsScript.new(clock, directory),
		SchedulerEventsScript.new(clock)]


func _encode_stores(commands: CommandsScript,
		scheduler: SchedulerEventsScript) -> PackedByteArray:
	"""Capture and encode an arbitrary pair of stores, for byte-identity comparisons."""
	var record: PendingCommands.Record = PendingCommands.Record.new()
	var refusal: SaveHeader.Refusal = PendingCommands.capture_into(commands, scheduler, record)
	if not refusal.is_ok():
		return PackedByteArray()
	return _encode(record)


func _decode_refusal(bytes: PackedByteArray, out: PendingCommands.Record) -> SaveHeader.Refusal:
	"""Decode into a caller-owned Record and hand back the refusal verbatim."""
	return PendingCommands.decode_into(bytes, 0, out)


func _assert_decode_refuses(bytes: PackedByteArray, code: StringName, message: String) -> void:
	"""A full-length but invalid section must refuse AND leave the caller's Record untouched."""
	var guard: PendingCommands.Record = PendingCommands.Record.new()
	var out: PendingCommands.Record = PendingCommands.Record.new()
	var refusal: SaveHeader.Refusal = _decode_refusal(bytes, out)
	assert_equal(refusal.code, code, message)
	assert_true(out.equals(guard), "%s must leave the caller's Record byte-identical" % message)


# --- layout constants ---------------------------------------------------------------------------------

func test_section_identity_matches_the_ruling() -> void:
	"""SAVE-SEQ-R01: section12 uses schema3 while SCHQ0001 remains schema1."""
	assert_equal(PendingCommands.SECTION_ID, 12, "ARCH-SAVE-002 numbers PENDING_COMMANDS 12")
	assert_equal(PendingCommands.SECTION_SCHEMA_VERSION, 3,
		"SAVE-SEQ-R01 advances only the section12 framing to schema3")
	assert_equal(PendingCommands.EXTENSION_SCHEMA_VERSION, 1,
		"the nested SCHQ0001 subsection stays at schema 1")
	assert_equal(PendingCommands.SECTION_TAG, "SCHQ0001", "the extension tag is SCHQ0001")


func test_owner_keys_are_in_ascii_order() -> void:
	"""`commands` precedes `scheduler_events`, and the bytes follow that order too."""
	assert_true(PendingCommands.OWNER_KEY_COMMANDS < PendingCommands.OWNER_KEY_SCHEDULER,
		"`commands` sorts before `scheduler_events` in ASCII")
	assert_equal(PendingCommands.OWNER_SCHEMA_VERSION_COMMANDS, 2,
		"the registry declares commands owner schema 2")
	assert_equal(PendingCommands.OWNER_SCHEMA_VERSION_SCHEDULER, 1,
		"the registry declares scheduler_events owner schema 1")
	assert_equal(PendingCommands.extension_offset_of(3, 17),
		PendingCommands.PREFIX_BYTES + 64 * 3 + 17,
		"the scheduler owner's bytes begin only after every economic byte")


func test_layout_arithmetic_is_the_contracts_own() -> void:
	"""`76 + 64*E + P + 32*S`, with the 28-byte prefix and the 48-byte extension fixed part."""
	assert_equal(PendingCommands.PREFIX_BYTES, 28, "the section 12 prefix is 28 bytes")
	assert_equal(PendingCommands.ECONOMIC_RECORD_BYTES, 64, "§8.1's command record is 64 bytes")
	assert_equal(PendingCommands.SCHEDULER_RECORD_BYTES, 32, "a scheduler record is 32 bytes")
	assert_equal(PendingCommands.EXTENSION_FIXED_BYTES, 48,
		"the extension's header and control block are 16 + 32 bytes")
	assert_equal(PendingCommands.extension_byte_length(0), 48, "X = 48 + 32*0")
	assert_equal(PendingCommands.extension_byte_length(256), 48 + 32 * 256, "X = 48 + 32*256")
	var record: PendingCommands.Record = PendingCommands.Record.new()
	assert_equal(PendingCommands.section_byte_length(record),
		PendingCommands.EMPTY_SECTION_BYTES, "an empty section 12 is 76 bytes, never 0")
	assert_equal(PendingCommands.MAX_SECTION_BYTES,
		76 + 64 * 4096 + 1048576 + 32 * 256, "the bound is 76 + 64*4096 + 1048576 + 32*256")


func test_extension_length_inverse_is_a_shape_predicate() -> void:
	"""S is recovered from X only when X is exactly `48 + 32*S`; anything else is refused."""
	assert_equal(PendingCommands.scheduler_count_of_extension_bytes(48), 0, "X=48 means S=0")
	assert_equal(PendingCommands.scheduler_count_of_extension_bytes(80), 1, "X=80 means S=1")
	assert_equal(PendingCommands.scheduler_count_of_extension_bytes(47), -1,
		"X below the fixed 48 bytes names no S")
	assert_equal(PendingCommands.scheduler_count_of_extension_bytes(49), -1,
		"X that is not 48 + 32*S names no S")


func test_declared_field_ordinals_match_the_registry() -> void:
	"""REG-R01's ordinals are binding, and they are NOT GDScript declaration order."""
	assert_equal(PendingCommands.FIELD_KEYS_COMMANDS.size(), 20,
		"the commands owner declares 20 canonical fields")
	assert_equal(PendingCommands.FIELD_KEYS_COMMANDS[0], &"_count", "ordinal 0 is _count")
	assert_equal(PendingCommands.FIELD_KEYS_COMMANDS[2], &"_next_sequence_high",
		"ordinal 2 is _next_sequence_high, ahead of the low half")
	assert_equal(PendingCommands.FIELD_KEYS_COMMANDS[4], &"_execute_tick",
		"ordinal 4 opens the record fields")
	assert_equal(PendingCommands.FIELD_KEYS_COMMANDS[19], &"_payload",
		"ordinal 19 is the payload arena")
	assert_equal(PendingCommands.FIELD_KEYS_SCHEDULER.size(), 14,
		"the scheduler_events owner declares 14 canonical fields")
	assert_equal(PendingCommands.FIELD_KEYS_SCHEDULER[0], &"_head", "ordinal 0 is _head")
	assert_equal(PendingCommands.FIELD_KEYS_SCHEDULER[6], &"_last_drained_boundary",
		"ordinal 6 closes the control scalars")
	assert_equal(PendingCommands.FIELD_KEYS_SCHEDULER[7], &"_boundary_tick",
		"ordinal 7 opens the record fields")


func test_record_field_ordinals_follow_the_wire_record_order() -> void:
	"""Ordinals 4..18 reproduce §8.1's 64-byte field order; 7..13 the 32-byte record's."""
	var economic: PackedInt32Array = PackedInt32Array([CommandsScript.OFFSET_EXECUTE_TICK,
		CommandsScript.OFFSET_PLAYER_ID, CommandsScript.OFFSET_SEQUENCE_LOW,
		CommandsScript.OFFSET_SEQUENCE_HIGH, CommandsScript.OFFSET_KIND,
		CommandsScript.OFFSET_TARGET_SLOT, CommandsScript.OFFSET_TARGET_GENERATION,
		CommandsScript.OFFSET_GOAL_X, CommandsScript.OFFSET_GOAL_Z, CommandsScript.OFFSET_ARG0,
		CommandsScript.OFFSET_ARG1, CommandsScript.OFFSET_PAYLOAD_OFFSET,
		CommandsScript.OFFSET_PAYLOAD_LENGTH, CommandsScript.OFFSET_FLAGS,
		CommandsScript.OFFSET_RESERVED_ZERO])
	for index: int in economic.size() - 1:
		assert_true(economic[index] < economic[index + 1],
			"commands ordinal %d must precede ordinal %d on the wire" % [index + 4, index + 5])
	var scheduler: PackedInt32Array = PackedInt32Array([
		SchedulerEventsScript.OFFSET_BOUNDARY_TICK, SchedulerEventsScript.OFFSET_SEQUENCE_LOW,
		SchedulerEventsScript.OFFSET_SEQUENCE_HIGH, SchedulerEventsScript.OFFSET_KIND,
		SchedulerEventsScript.OFFSET_REASON, SchedulerEventsScript.OFFSET_VALUE,
		SchedulerEventsScript.OFFSET_RESERVED])
	for index: int in scheduler.size() - 1:
		assert_true(scheduler[index] < scheduler[index + 1],
			"scheduler ordinal %d must precede ordinal %d" % [index + 7, index + 8])


# --- pinned byte vectors ------------------------------------------------------------------------------

func test_empty_section_bytes_are_pinned() -> void:
	"""The 76 empty bytes, pinned so a constant rename cannot move a field unnoticed."""
	var bytes: PackedByteArray = _encoded_world()
	assert_equal(bytes.size(), 76, "an empty section 12 occupies 76 bytes")
	assert_equal(bytes.hex_encode(), _empty_section_hex(), "the empty section is byte-pinned")
	assert_equal(bytes.decode_u32(0), 3, "the first u32 is the section schema 3")
	assert_equal(bytes.decode_u32(12), 48, "scheduler_extension_bytes is 48 when S is 0")
	assert_equal(bytes.slice(28, 36).get_string_from_ascii(), "SCHQ0001",
		"the extension tag begins immediately after the prefix when E and P are 0")
	assert_equal(bytes.decode_s64(44 + 16), -1,
		"last_drained_boundary starts at NO_PRIOR_DRAIN")


func test_one_command_and_one_event_bytes_are_pinned() -> void:
	"""177 pinned bytes: prefix, one 64-byte record, five payload bytes, one 32-byte event."""
	assert_true(_submit(8, 5, PackedByteArray([1, 2, 3, 4, 5])), "DESIGNATE_ZONE must queue")
	assert_true(_submit_speed(2), "a speed-2 event must queue")
	var bytes: PackedByteArray = _encoded_world()
	assert_equal(bytes.size(), 177, "76 + 64 + 5 + 32 = 177")
	assert_equal(bytes.hex_encode(), _one_each_section_hex(), "the section is byte-pinned")
	assert_equal(bytes.decode_u32(4), 1, "E is 1")
	assert_equal(bytes.decode_u32(8), 5, "P is 5")
	assert_equal(bytes.decode_u32(12), 80, "X is 48 + 32*1")
	assert_equal(bytes.slice(92, 97), PackedByteArray([1, 2, 3, 4, 5]),
		"the payload arena's used prefix follows the records verbatim")
	assert_equal(bytes.slice(97, 105).get_string_from_ascii(), "SCHQ0001",
		"the scheduler owner's block begins at 28 + 64*E + P")


func test_descriptor_row_count_is_both_live_windows() -> void:
	"""§12 serializes no unused row, so its descriptor row_count cannot be a ring capacity."""
	assert_true(_submit(8, 0, PackedByteArray()), "a command must queue")
	assert_true(_submit(9, 0, PackedByteArray()), "a second command must queue")
	assert_true(_submit_speed(4), "a speed event must queue")
	var record: PendingCommands.Record = _capture()
	assert_equal(PendingCommands.descriptor_row_count(record), 3,
		"two pending commands and one pending event are three rows")
	assert_equal(PendingCommands.section_byte_length(record), 236,
		"two empty-payload commands and one event occupy 76 + 64*2 + 0 + 32 = 236 bytes")


# --- round trips --------------------------------------------------------------------------------------

func test_round_trip_is_byte_identical() -> void:
	"""capture -> encode -> decode -> apply -> re-encode must produce the same bytes."""
	assert_true(_submit(3, 11, PackedByteArray([9, 8, 7])), "a command must queue")
	assert_true(_submit(20, 2, PackedByteArray([4])), "a second command must queue")
	assert_true(_submit_speed(4), "a speed event must queue")
	var first: PackedByteArray = _encoded_world()
	var decoded: PendingCommands.Record = PendingCommands.Record.new()
	var refusal: SaveHeader.Refusal = _decode_refusal(first, decoded)
	assert_equal(refusal.code, PendingCommands.REFUSE_NONE, "a clean section decodes")
	var world: Array = _fresh_world()
	var applied: SaveHeader.Refusal = _apply_with_barrier(decoded,
		world[2] as CommandsScript, world[3] as SchedulerEventsScript, 0)
	assert_equal(applied.code, PendingCommands.REFUSE_NONE,
		"a clean section applies: %s" % applied.detail)
	assert_equal(_encode_stores(world[2] as CommandsScript,
		world[3] as SchedulerEventsScript), first,
		"the restored world must re-encode to the same bytes")


func test_round_trip_survives_a_wrapped_economic_head() -> void:
	"""A queue whose ring head has wrapped past 4096 still encodes in QUEUE order, not row order."""
	for cycle: int in CommandsScript.QUEUE_CAPACITY + 4:
		assert_true(_submit(0, cycle, PackedByteArray()), "cycle %d must queue" % cycle)
		var drained: CommandsScript.Command = CommandsScript.Command.new()
		assert_true(_commands.drain_due_into(1, drained), "cycle %d must drain" % cycle)
	assert_equal(_commands.pending_count(), 0, "the ring is empty after the wrap")
	assert_true(_submit(1, 101, PackedByteArray([1])), "first post-wrap command must queue")
	assert_true(_submit(2, 102, PackedByteArray([2, 2])), "second must queue")
	assert_true(_submit(3, 103, PackedByteArray([3, 3, 3])), "third must queue")
	var bytes: PackedByteArray = _encoded_world()
	assert_equal(bytes.decode_s32(28 + CommandsScript.OFFSET_ARG0), 101,
		"the wrapped head must put the oldest pending command first")
	assert_equal(bytes.decode_s32(28 + 64 + CommandsScript.OFFSET_ARG0), 102,
		"queue position 1 is the second pending command, whatever row holds it")
	assert_equal(bytes.decode_s32(28 + 128 + CommandsScript.OFFSET_ARG0), 103,
		"queue position 2 is the third pending command")
	assert_equal(bytes.slice(28 + 192, 28 + 192 + 6), PackedByteArray([1, 2, 2, 3, 3, 3]),
		"the arena carries the three payloads in queue order and nothing else")


func test_round_trip_survives_a_wrapped_scheduler_head() -> void:
	"""The scheduler ring wraps past 256 and its stored head is still the canonical 0."""
	for cycle: int in SchedulerEventsScript.QUEUE_CAPACITY + 4:
		assert_true(_submit_speed(1 + cycle % 2), "cycle %d must queue" % cycle)
		assert_equal(_scheduler.pump(), 1, "cycle %d must apply exactly one event" % cycle)
	assert_true(_scheduler.head_position() != 0, "the scheduler ring head has wrapped")
	assert_true(_submit_speed(4), "the first post-wrap event must queue")
	assert_true(_submit_speed(2), "the second post-wrap event must queue")
	var bytes: PackedByteArray = _encoded_world()
	var control: int = 28 + SchedulerEventsScript.EXTENSION_HEADER_BYTES
	assert_equal(bytes.decode_s32(control + SchedulerEventsScript.OFFSET_CONTROL_HEAD), 0,
		"the stored head is the canonical 0, never the live ring head")
	assert_equal(bytes.decode_s32(control + SchedulerEventsScript.OFFSET_CONTROL_COUNT), 2,
		"the stored count is the live window")
	var first: int = 28 + SchedulerEventsScript.EXTENSION_FIXED_BYTES
	assert_equal(bytes.decode_s32(first + SchedulerEventsScript.OFFSET_VALUE), 4,
		"queue position 0 is the older pending event")
	assert_equal(bytes.decode_s32(first + 32 + SchedulerEventsScript.OFFSET_VALUE), 2,
		"queue position 1 is the newer pending event")


func test_wrapped_scheduler_queue_restores_in_order() -> void:
	"""A wrapped scheduler ring restores from row 0 and applies its events in the saved order."""
	for cycle: int in SchedulerEventsScript.QUEUE_CAPACITY + 9:
		assert_true(_submit_speed(2), "cycle %d must queue" % cycle)
		assert_equal(_scheduler.pump(), 1, "cycle %d must apply" % cycle)
	assert_true(_submit_speed(4), "a pending event must queue")
	assert_true(_submit_speed(1), "a second pending event must queue")
	var bytes: PackedByteArray = _encoded_world()
	var decoded: PendingCommands.Record = PendingCommands.Record.new()
	assert_equal(_decode_refusal(bytes, decoded).code, PendingCommands.REFUSE_NONE,
		"the wrapped queue decodes")
	var world: Array = _fresh_world()
	var scheduler: SchedulerEventsScript = world[3] as SchedulerEventsScript
	assert_equal(_apply_with_barrier(decoded, world[2] as CommandsScript, scheduler, 0).code,
		PendingCommands.REFUSE_NONE, "the wrapped queue applies")
	assert_equal(scheduler.head_position(), 0, "a restored queue starts at row 0")
	var event: SchedulerEventsScript.Event = SchedulerEventsScript.Event.new()
	assert_true(scheduler.read_into(0, event), "the restored queue has a first event")
	assert_equal(event.value, 4, "the restored order is the saved order")
	assert_true(scheduler.read_into(1, event), "the restored queue has a second event")
	assert_equal(event.value, 1, "the second restored event is the second saved one")


# --- the int32/int64 sign trap ---------------------------------------------------------------------------

func test_economic_sequence_at_the_u32_sign_bit_round_trips() -> void:
	"""A session sequence of 0x80000000 stores a NEGATIVE i32 and must come back unchanged."""
	var bits: int = SaveCodec.u32_bits_to_int32(2147483648)
	assert_equal(bits, -2147483648, "0x80000000 read as int32 is -2147483648")
	assert_equal(SaveCodec.int32_bits_to_u32(bits), 2147483648,
		"and reading it back unsigned restores 0x80000000")
	assert_true(_commands.restore_sequence(0, 2147483648), "the queue accepts that sequence")
	assert_true(_submit(8, 1, PackedByteArray()), "the stamped command must queue")
	var bytes: PackedByteArray = _encoded_world()
	assert_equal(bytes.decode_u32(28 + CommandsScript.OFFSET_SEQUENCE_LOW), 2147483648,
		"the wire carries the u32 BITS, not a sign-extended value")
	var record: PendingCommands.Record = _capture()
	assert_equal(record.sequence_low[0], bits, "the column carries the i32 spelling")
	var decoded: PendingCommands.Record = PendingCommands.Record.new()
	assert_equal(_decode_refusal(bytes, decoded).code, PendingCommands.REFUSE_NONE,
		"a boundary sequence decodes")
	assert_equal(decoded.sequence_low[0], bits, "and decodes back to the same i32 spelling")
	assert_equal(decoded.economic_next_sequence_low, 2147483649,
		"the allocator stays unsigned across the boundary")


func test_economic_key_order_is_unsigned_across_the_sign_bit() -> void:
	"""0x7fffffff must precede 0x80000000. A signed comparison reverses them."""
	assert_true(_commands.restore_sequence(0, 2147483647), "sequence 0x7fffffff is accepted")
	assert_true(_submit(8, 1, PackedByteArray()), "the 0x7fffffff command must queue")
	assert_true(_submit(8, 2, PackedByteArray()), "the 0x80000000 command must queue")
	var bytes: PackedByteArray = _encoded_world()
	assert_equal(bytes.decode_u32(28 + CommandsScript.OFFSET_SEQUENCE_LOW), 2147483647,
		"queue position 0 holds 0x7fffffff")
	assert_equal(bytes.decode_u32(28 + 64 + CommandsScript.OFFSET_SEQUENCE_LOW), 2147483648,
		"queue position 1 holds 0x80000000, AFTER it")
	var decoded: PendingCommands.Record = PendingCommands.Record.new()
	assert_equal(_decode_refusal(bytes, decoded).code, PendingCommands.REFUSE_NONE,
		"the unsigned ordering is accepted")
	assert_equal(decoded.sequence_low[0], 2147483647, "the first key stays positive")
	assert_equal(decoded.sequence_low[1], SaveCodec.u32_bits_to_int32(2147483648),
		"and the second is the negative i32 spelling of the larger unsigned key")


func test_reversed_sign_bit_keys_are_refused() -> void:
	"""A section whose two records read in order only under a SIGNED comparison must refuse."""
	assert_true(_commands.restore_sequence(0, 2147483647), "sequence 0x7fffffff is accepted")
	assert_true(_submit(8, 1, PackedByteArray()), "the 0x7fffffff command must queue")
	assert_true(_submit(8, 2, PackedByteArray()), "the 0x80000000 command must queue")
	var bytes: PackedByteArray = _encoded_world()
	var swapped: PackedByteArray = bytes.duplicate()
	for index: int in 64:
		swapped[28 + index] = bytes[28 + 64 + index]
		swapped[28 + 64 + index] = bytes[28 + index]
	_assert_decode_refuses(swapped, PendingCommands.REFUSE_KEY_ORDER,
		"records ordered 0x80000000 before 0x7fffffff")


func test_scheduler_sequence_at_the_u32_sign_bit_round_trips() -> void:
	"""The scheduler's own sequence space crosses the same boundary and is masked the same way."""
	assert_true(_scheduler.restore_sequence(0, 2147483648), "the queue accepts that sequence")
	assert_true(_submit_speed(4), "the stamped event must queue")
	var bytes: PackedByteArray = _encoded_world()
	var first: int = 28 + SchedulerEventsScript.EXTENSION_FIXED_BYTES
	assert_equal(bytes.decode_u32(first + SchedulerEventsScript.OFFSET_SEQUENCE_LOW), 2147483648,
		"the wire carries the u32 bits")
	var decoded: PendingCommands.Record = PendingCommands.Record.new()
	assert_equal(_decode_refusal(bytes, decoded).code, PendingCommands.REFUSE_NONE,
		"a boundary scheduler sequence decodes")
	assert_equal(decoded.event_sequence_low[0], SaveCodec.u32_bits_to_int32(2147483648),
		"the column carries the i32 spelling")
	assert_equal(decoded.scheduler_next_sequence_low, 2147483649,
		"and the allocator stays unsigned")


func test_scheduler_sequence_read_signed_would_break_the_applied_gate() -> void:
	"""last_applied 0x7fffffff before a pending 0x80000000 is legal ONLY under unsigned order."""
	assert_true(_scheduler.restore_sequence(0, 2147483647), "sequence 0x7fffffff is accepted")
	assert_true(_submit_speed(2), "the 0x7fffffff event must queue")
	assert_equal(_scheduler.pump(), 1, "it applies, moving last_applied to 0x7fffffff")
	assert_true(_submit_speed(4), "the 0x80000000 event must queue")
	var bytes: PackedByteArray = _encoded_world()
	var control: int = 28 + SchedulerEventsScript.EXTENSION_HEADER_BYTES
	assert_equal(bytes.decode_u32(
		control + SchedulerEventsScript.OFFSET_CONTROL_LAST_APPLIED_SEQUENCE_LOW), 2147483647,
		"last_applied is the u32 0x7fffffff")
	var decoded: PendingCommands.Record = PendingCommands.Record.new()
	assert_equal(_decode_refusal(bytes, decoded).code, PendingCommands.REFUSE_NONE,
		"the pending 0x80000000 legitimately exceeds the applied 0x7fffffff")
	assert_equal(decoded.scheduler_last_applied_low, 2147483647,
		"the control block's unsigned last_applied survives")


# --- ring garbage ---------------------------------------------------------------------------------------

func test_drained_rows_leave_no_trace_in_the_record() -> void:
	"""Two worlds with identical pending queues and different drain histories encode identically."""
	assert_true(_submit(11, 77, PackedByteArray([5, 5, 5, 5])), "a command to be drained")
	assert_true(_submit(12, 78, PackedByteArray([6, 6])), "a second command to be drained")
	var drained: CommandsScript.Command = CommandsScript.Command.new()
	assert_true(_commands.drain_due_into(1, drained), "the first drains")
	assert_true(_commands.drain_due_into(1, drained), "the second drains")
	assert_true(_submit_speed(4), "a scheduler event to be drained")
	assert_equal(_scheduler.pump(), 1, "it applies")
	assert_true(_submit(8, 1, PackedByteArray([1])), "the surviving command")
	assert_true(_submit_speed(2), "the surviving event")
	var dirty: PackedByteArray = _encoded_world()
	var record: PendingCommands.Record = _capture()
	assert_equal(record.economic_count, 1, "one economic command survives")
	assert_equal(record.payload_used, 1, "and the arena cursor names only its byte")
	assert_equal(record.execute_tick[1], 0,
		"the drained row past the window holds the canonical unused tick")
	assert_equal(record.target_slot[1], EntityDirectoryScript.NULL_SLOT,
		"the declared canonical unused target slot is -1, not 0")
	assert_equal(record.event_value[1], 0,
		"the drained scheduler row past the window holds zero")
	assert_true(dirty.size() > 0, "the dirty world encodes")


func test_a_record_carrying_ring_garbage_is_refused() -> void:
	"""A Record whose tail holds a drained row must refuse, not silently encode it."""
	assert_true(_submit(8, 1, PackedByteArray()), "one pending command")
	var record: PendingCommands.Record = _capture()
	record.arg0[1] = 4242
	var refusal: SaveHeader.Refusal = PendingCommands.record_refusal(record)
	assert_equal(refusal.code, PendingCommands.REFUSE_RING_TAIL_GARBAGE,
		"a nonzero economic row past the window is garbage")
	var clean: PendingCommands.Record = _capture()
	clean.event_reason[0] = 7
	assert_equal(PendingCommands.record_refusal(clean).code,
		PendingCommands.REFUSE_RING_TAIL_GARBAGE,
		"a nonzero scheduler row past the window is garbage")


func test_arena_bytes_no_command_owns_must_be_zero() -> void:
	"""A used prefix carrying a drained command's leftover bytes is refused, not persisted."""
	assert_true(_submit(8, 1, PackedByteArray([1, 2, 3, 4, 5])), "one pending command")
	var bytes: PackedByteArray = _encoded_world()
	var forged: PackedByteArray = bytes.duplicate()
	forged.encode_u32(8, 8)
	var tail: PackedByteArray = PackedByteArray([200, 201, 202])
	var rebuilt: PackedByteArray = forged.slice(0, 93)
	rebuilt.append_array(tail)
	rebuilt.append_array(forged.slice(93, forged.size()))
	assert_equal(rebuilt.size(), bytes.size() + 3, "the forged section is three bytes longer")
	_assert_decode_refuses(rebuilt, PendingCommands.REFUSE_PAYLOAD_GARBAGE,
		"arena bytes no pending command owns")


func test_arena_bytes_between_two_spans_must_be_zero() -> void:
	"""The dead region is not always a suffix: a drained command can leave a HOLE between spans."""
	assert_true(_submit(8, 1, PackedByteArray([1, 2, 3])), "the first command")
	assert_true(_submit(8, 2, PackedByteArray([4, 5])), "the second command")
	var bytes: PackedByteArray = _encoded_world()
	assert_equal(bytes.decode_u32(8), 5, "the honest arena holds five bytes")
	var forged: PackedByteArray = bytes.duplicate()
	forged.encode_u32(8, 7)
	forged.encode_s32(28 + 64 + CommandsScript.OFFSET_PAYLOAD_OFFSET, 5)
	var rebuilt: PackedByteArray = forged.slice(0, 28 + 128 + 3)
	rebuilt.append_array(PackedByteArray([170, 187]))
	rebuilt.append_array(forged.slice(28 + 128 + 3, forged.size()))
	assert_equal(rebuilt.size(), bytes.size() + 2, "the hole adds exactly two bytes")
	_assert_decode_refuses(rebuilt, PendingCommands.REFUSE_PAYLOAD_GARBAGE,
		"a nonzero hole between two pending payload spans")


func test_overlapping_payload_spans_are_refused() -> void:
	"""Two pending commands cannot own the same arena byte."""
	assert_true(_submit(8, 1, PackedByteArray([1, 2, 3])), "the first command")
	assert_true(_submit(8, 2, PackedByteArray([4, 5, 6])), "the second command")
	var bytes: PackedByteArray = _encoded_world()
	var forged: PackedByteArray = bytes.duplicate()
	forged.encode_s32(28 + 64 + CommandsScript.OFFSET_PAYLOAD_OFFSET, 1)
	_assert_decode_refuses(forged, PendingCommands.REFUSE_PAYLOAD_OVERLAP,
		"two spans claiming the same arena byte")


# --- refusals, every one against a FULL-LENGTH section -------------------------------------------------

func test_nonzero_reserved_word_is_refused() -> void:
	"""§8.1 names `reserved_zero`, so a nonzero one refuses rather than being normalized away."""
	assert_true(_submit(8, 1, PackedByteArray()), "one pending command")
	var forged: PackedByteArray = _encoded_world()
	forged.encode_s32(28 + CommandsScript.OFFSET_RESERVED_ZERO, 1)
	_assert_decode_refuses(forged, PendingCommands.REFUSE_RESERVED_NONZERO,
		"a nonzero reserved word in a full-length section")


func test_nonzero_flags_are_refused() -> void:
	"""No specification defines a flag bit, so an accepted one would be an invented semantic."""
	assert_true(_submit(8, 1, PackedByteArray()), "one pending command")
	var forged: PackedByteArray = _encoded_world()
	forged.encode_s32(28 + CommandsScript.OFFSET_FLAGS, 1)
	_assert_decode_refuses(forged, PendingCommands.REFUSE_FLAGS_UNDEFINED,
		"an undefined flag bit in a full-length section")


func test_unknown_command_kind_is_refused() -> void:
	"""ARCH-CMD-003 compiles 24 ids and rejects anything else."""
	assert_true(_submit(8, 1, PackedByteArray()), "one pending command")
	var forged: PackedByteArray = _encoded_world()
	forged.encode_s32(28 + CommandsScript.OFFSET_KIND, CatalogScript.COMMAND_KIND.size())
	_assert_decode_refuses(forged, PendingCommands.REFUSE_UNKNOWN_KIND,
		"a kind one past the compiled domain")


func test_foreign_player_id_is_refused() -> void:
	"""ARCH-CMD-001: "Player ID is 0 in release 1". Any other id refuses, never remaps."""
	assert_true(_submit(8, 1, PackedByteArray()), "one pending command")
	var forged: PackedByteArray = _encoded_world()
	forged.encode_s32(28 + CommandsScript.OFFSET_PLAYER_ID, 1)
	_assert_decode_refuses(forged, PendingCommands.REFUSE_PLAYER_ID,
		"a player id release 1 does not have")


func test_malformed_null_target_is_refused() -> void:
	"""The null reference is `(-1, 0)`; a -1 slot carrying a generation is malformed."""
	assert_true(_submit(8, 1, PackedByteArray()), "one pending command")
	var forged: PackedByteArray = _encoded_world()
	forged.encode_s32(28 + CommandsScript.OFFSET_TARGET_GENERATION, 3)
	_assert_decode_refuses(forged, PendingCommands.REFUSE_TARGET_MALFORMED,
		"a null slot carrying a nonzero generation")


func test_nonzero_scheduler_head_is_refused() -> void:
	"""The contract stores the canonical head 0; anything else would restore a rotated ring."""
	assert_true(_submit_speed(2), "one pending event")
	var forged: PackedByteArray = _encoded_world()
	forged.encode_s32(28 + SchedulerEventsScript.EXTENSION_HEADER_BYTES
		+ SchedulerEventsScript.OFFSET_CONTROL_HEAD, 1)
	_assert_decode_refuses(forged, PendingCommands.REFUSE_HEAD_NOT_CANONICAL,
		"a stored ring head other than 0")


func test_nonzero_scheduler_reserved_padding_is_refused() -> void:
	"""ARCH-SAVE-005 rejects nonzero padding; the scheduler record's `reserved` is padding."""
	assert_true(_submit_speed(2), "one pending event")
	var forged: PackedByteArray = _encoded_world()
	forged.encode_s32(28 + SchedulerEventsScript.EXTENSION_FIXED_BYTES
		+ SchedulerEventsScript.OFFSET_RESERVED, 9)
	_assert_decode_refuses(forged, PendingCommands.REFUSE_RESERVED_NONZERO,
		"nonzero scheduler record padding")


func test_scheduler_events_at_two_boundaries_are_refused() -> void:
	"""Every pending event waits at ONE boundary: the saved completed tick."""
	assert_true(_submit_speed(2), "the first pending event")
	assert_true(_submit_speed(4), "the second pending event")
	var forged: PackedByteArray = _encoded_world()
	forged.encode_s64(28 + SchedulerEventsScript.EXTENSION_FIXED_BYTES + 32
		+ SchedulerEventsScript.OFFSET_BOUNDARY_TICK, 5)
	_assert_decode_refuses(forged, PendingCommands.REFUSE_BOUNDARY_MISMATCH,
		"two pending events waiting at different boundaries")


func test_non_increasing_scheduler_sequence_is_refused() -> void:
	"""Ring order IS canonical order here, so two events may never share or reverse a sequence."""
	assert_true(_submit_speed(2), "the first pending event")
	assert_true(_submit_speed(4), "the second pending event")
	var forged: PackedByteArray = _encoded_world()
	var first: int = 28 + SchedulerEventsScript.EXTENSION_FIXED_BYTES
	forged.encode_u32(first + 32 + SchedulerEventsScript.OFFSET_SEQUENCE_LOW,
		forged.decode_u32(first + SchedulerEventsScript.OFFSET_SEQUENCE_LOW))
	_assert_decode_refuses(forged, PendingCommands.REFUSE_SEQUENCE_ORDER,
		"two events sharing one sequence")


func test_exhausted_scheduler_sentinel_is_never_a_pending_event() -> void:
	"""`(0, 0)` is the exhaustion sentinel and can never be a real event's sequence."""
	assert_true(_submit_speed(2), "one pending event")
	var forged: PackedByteArray = _encoded_world()
	var first: int = 28 + SchedulerEventsScript.EXTENSION_FIXED_BYTES
	forged.encode_u32(first + SchedulerEventsScript.OFFSET_SEQUENCE_LOW, 0)
	forged.encode_u32(first + SchedulerEventsScript.OFFSET_SEQUENCE_HIGH, 0)
	_assert_decode_refuses(forged, PendingCommands.REFUSE_SEQUENCE_ORDER,
		"the exhausted sentinel used as an event sequence")


func test_extension_payload_length_must_agree_with_the_body() -> void:
	"""The nested subsection's own length field is checked against the prefix and the bytes."""
	assert_true(_submit_speed(2), "one pending event")
	var forged: PackedByteArray = _encoded_world()
	forged.encode_u32(28 + SchedulerEventsScript.OFFSET_EXTENSION_PAYLOAD_LENGTH, 32)
	_assert_decode_refuses(forged, PendingCommands.REFUSE_EXTENSION_LENGTH,
		"a SCHQ0001 payload length that disagrees with the body")


func test_prefix_extension_bytes_must_agree_with_the_body() -> void:
	"""`scheduler_extension_bytes` fixes S, so a wrong one moves the section's whole length."""
	assert_true(_submit_speed(2), "one pending event")
	var shrunk: PackedByteArray = _encoded_world()
	shrunk.encode_u32(12, 48)
	_assert_decode_refuses(shrunk, PendingCommands.REFUSE_EXTENSION_LENGTH,
		"a prefix claiming S=0 over a body holding one event")
	var grown: PackedByteArray = _encoded_world()
	grown.encode_u32(12, 48 + 32 * 2)
	_assert_decode_refuses(grown, PendingCommands.REFUSE_TRUNCATED,
		"a prefix claiming S=2 over a body holding one event")


func test_extension_tag_must_sit_after_every_economic_byte() -> void:
	"""Owner block order: `commands` first, `scheduler_events` second. Swapping them refuses."""
	assert_true(_submit(8, 1, PackedByteArray([1, 2, 3])), "one pending command")
	assert_true(_submit_speed(2), "one pending event")
	var bytes: PackedByteArray = _encoded_world()
	var economic: PackedByteArray = bytes.slice(28, 28 + 64 + 3)
	var extension: PackedByteArray = bytes.slice(28 + 64 + 3, bytes.size())
	var swapped: PackedByteArray = bytes.slice(0, 28)
	swapped.append_array(extension)
	swapped.append_array(economic)
	assert_equal(swapped.size(), bytes.size(), "the swap moves bytes, it does not add any")
	_assert_decode_refuses(swapped, PendingCommands.REFUSE_EXTENSION_TAG,
		"the scheduler owner's block placed ahead of the economic one")


func test_wrong_extension_tag_is_refused() -> void:
	"""A subsection that is not `SCHQ0001` is not this extension, whatever its length says."""
	assert_true(_submit_speed(2), "one pending event")
	var forged: PackedByteArray = _encoded_world()
	forged.encode_u8(28, "s".unicode_at(0))
	_assert_decode_refuses(forged, PendingCommands.REFUSE_EXTENSION_TAG,
		"a lowercased extension tag")


func test_wrong_extension_schema_version_is_refused() -> void:
	"""SAVE-R09-001 keeps the nested SCHQ0001 at schema 1; an unknown version refuses."""
	assert_true(_submit_speed(2), "one pending event")
	var forged: PackedByteArray = _encoded_world()
	forged.encode_u32(28 + SchedulerEventsScript.OFFSET_EXTENSION_SCHEMA_VERSION, 2)
	_assert_decode_refuses(forged, PendingCommands.REFUSE_EXTENSION_VERSION,
		"an unknown SCHQ0001 schema version")


func test_wrong_section_schema_is_refused() -> void:
	"""§12 is schema 3; schema 1 is a different, unmigrated layout and is not silently reused."""
	var forged: PackedByteArray = _encoded_world()
	forged.encode_u32(0, 1)
	_assert_decode_refuses(forged, PendingCommands.REFUSE_SECTION_SCHEMA,
		"a section 12 claiming schema 1")


# --- the extent gate ------------------------------------------------------------------------------------

func test_extent_refusal_is_the_primary_gate() -> void:
	"""It is public because it must be testable alone: a slack extent check would hide."""
	var bytes: PackedByteArray = _encoded_world()
	assert_equal(PendingCommands.extent_refusal(bytes, 0).code, PendingCommands.REFUSE_NONE,
		"a whole section at offset 0 passes")
	assert_equal(PendingCommands.extent_refusal(bytes, -1).code,
		PendingCommands.REFUSE_NEGATIVE_OFFSET, "a negative offset refuses")
	assert_equal(PendingCommands.extent_refusal(bytes, 1).code,
		PendingCommands.REFUSE_SECTION_SCHEMA,
		"one byte past the start the prefix is not a section 12 prefix at all")
	assert_equal(PendingCommands.extent_refusal(bytes.slice(0, 75), 0).code,
		PendingCommands.REFUSE_TRUNCATED, "75 bytes cannot hold the 76-byte empty section")
	assert_equal(PendingCommands.extent_refusal(bytes.slice(0, 27), 0).code,
		PendingCommands.REFUSE_TRUNCATED, "27 bytes cannot even hold the 28-byte prefix")
	assert_equal(PendingCommands.extent_refusal(PackedByteArray(), 0).code,
		PendingCommands.REFUSE_TRUNCATED, "an empty buffer has no prefix")


func test_extent_refusal_bounds_every_declared_count() -> void:
	"""E, P and S are bounded BEFORE the length multiplication, per SAVE-LAYOUT-R01."""
	var bytes: PackedByteArray = _encoded_world()
	var forged: PackedByteArray = bytes.duplicate()
	forged.encode_u32(4, CommandsScript.QUEUE_CAPACITY + 1)
	assert_equal(PendingCommands.extent_refusal(forged, 0).code,
		PendingCommands.REFUSE_ECONOMIC_COUNT, "E above 4096 refuses")
	forged = bytes.duplicate()
	forged.encode_u32(8, CommandsScript.PAYLOAD_ARENA_BYTES + 1)
	assert_equal(PendingCommands.extent_refusal(forged, 0).code,
		PendingCommands.REFUSE_PAYLOAD_USED, "P above 1048576 refuses")
	forged = bytes.duplicate()
	forged.encode_u32(12, 48 + 32 * (SchedulerEventsScript.QUEUE_CAPACITY + 1))
	assert_equal(PendingCommands.extent_refusal(forged, 0).code,
		PendingCommands.REFUSE_SCHEDULER_COUNT, "S above 256 refuses, and is named as S")
	forged = bytes.duplicate()
	forged.encode_u32(12, 49)
	assert_equal(PendingCommands.extent_refusal(forged, 0).code,
		PendingCommands.REFUSE_EXTENSION_LENGTH, "an X that is not 48 + 32*S refuses")


func test_section_tiles_at_a_nonzero_offset_with_no_gaps() -> void:
	"""§12 is decoded from wherever the section directory says it starts, with nothing skipped."""
	assert_true(_submit(8, 1, PackedByteArray([7, 7])), "one pending command")
	assert_true(_submit_speed(4), "one pending event")
	var section: PackedByteArray = _encoded_world()
	var lead: PackedByteArray = PackedByteArray([9, 9, 9, 9, 9])
	var file: PackedByteArray = lead.duplicate()
	file.append_array(section)
	file.append_array(PackedByteArray([3, 3, 3]))
	var decoded: PendingCommands.Record = PendingCommands.Record.new()
	assert_equal(PendingCommands.decode_into(file, lead.size(), decoded).code,
		PendingCommands.REFUSE_NONE, "the section decodes at its own offset")
	assert_equal(PendingCommands.section_byte_length(decoded), section.size(),
		"and its computed length is exactly the bytes it occupied, so the next section abuts")
	assert_equal(PendingCommands.section_length_refusal(section.size(), decoded).code,
		PendingCommands.REFUSE_NONE, "the descriptor length agrees")
	assert_equal(PendingCommands.section_length_refusal(section.size() + 1, decoded).code,
		PendingCommands.REFUSE_LENGTH, "a descriptor one byte long refuses")


# --- the calendar boundary payload -----------------------------------------------------------------------

func test_commands_due_at_first_midnight_round_trip() -> void:
	"""Saved at 13499 with an edit due at 13500 -- GDD §5.1's first midnight, not `% 18000 == 0`."""
	_set_completed_tick(FIRST_MIDNIGHT_TICK - 1)
	assert_true(_submit(8, 1, PackedByteArray([1])), "an edit at the midnight boundary must queue")
	assert_true(_submit_speed(2), "and a scheduler event at the same boundary")
	var bytes: PackedByteArray = _encoded_world()
	assert_equal(bytes.decode_s64(28 + CommandsScript.OFFSET_EXECUTE_TICK), FIRST_MIDNIGHT_TICK,
		"the edit is due exactly at the first midnight")
	assert_equal(bytes.decode_s64(28 + 64 + 1 + SchedulerEventsScript.EXTENSION_FIXED_BYTES
		+ SchedulerEventsScript.OFFSET_BOUNDARY_TICK), FIRST_MIDNIGHT_TICK - 1,
		"the event waits at the saved completed tick, one before it")
	var decoded: PendingCommands.Record = PendingCommands.Record.new()
	assert_equal(_decode_refusal(bytes, decoded).code, PendingCommands.REFUSE_NONE,
		"the midnight section decodes")
	var world: Array = _fresh_world()
	(world[0] as SimClockScript).restore_runtime(FIRST_MIDNIGHT_TICK - 1, 0, 1, 0, 0, 0, 0, 0, 0, 0)
	assert_equal(_apply_with_barrier(decoded, world[2] as CommandsScript,
		world[3] as SchedulerEventsScript, FIRST_MIDNIGHT_TICK - 1).code,
		PendingCommands.REFUSE_NONE, "and applies against a clock restored to 13499")


func test_commands_due_at_a_day_boundary_round_trip() -> void:
	"""Tick 18000 is a day boundary in the offset calendar; 0 modulo 18000 is 06:00, not midnight."""
	_set_completed_tick(TICKS_PER_DAY - 1)
	assert_true(_submit(20, 4, PackedByteArray()), "an edit at the day boundary must queue")
	var bytes: PackedByteArray = _encoded_world()
	assert_equal(bytes.decode_s64(28 + CommandsScript.OFFSET_EXECUTE_TICK), TICKS_PER_DAY,
		"the edit is due at tick 18000")
	var decoded: PendingCommands.Record = PendingCommands.Record.new()
	assert_equal(_decode_refusal(bytes, decoded).code, PendingCommands.REFUSE_NONE,
		"the day-boundary section decodes")
	var world: Array = _fresh_world()
	(world[0] as SimClockScript).restore_runtime(TICKS_PER_DAY - 1, 0, 1, 0, 0, 0, 0, 0, 0, 0)
	assert_equal(_apply_with_barrier(decoded, world[2] as CommandsScript,
		world[3] as SchedulerEventsScript, TICKS_PER_DAY - 1).code,
		PendingCommands.REFUSE_NONE, "and applies against a clock restored to 17999")
	assert_equal((world[2] as CommandsScript).next_execute_tick(), TICKS_PER_DAY,
		"the restored queue still stamps the same next tick")


# --- apply ------------------------------------------------------------------------------------------------

func test_apply_restores_payload_bytes_verbatim() -> void:
	"""A restored command's opaque payload must come back byte for byte."""
	assert_true(_submit(8, 1, PackedByteArray([17, 0, 255, 128, 1])), "one payload-carrying command")
	var decoded: PendingCommands.Record = PendingCommands.Record.new()
	assert_equal(_decode_refusal(_encoded_world(), decoded).code, PendingCommands.REFUSE_NONE,
		"the section decodes")
	var world: Array = _fresh_world()
	var commands: CommandsScript = world[2] as CommandsScript
	assert_equal(_apply_with_barrier(decoded, commands,
		world[3] as SchedulerEventsScript, 0).code, PendingCommands.REFUSE_NONE, "it applies")
	var command: CommandsScript.Command = CommandsScript.Command.new()
	assert_true(commands.read_into(0, command), "the restored queue has the command")
	var out: PackedByteArray = PackedByteArray()
	out.resize(command.payload_length)
	assert_true(commands.read_payload_into(command, out), "its payload is readable")
	assert_equal(out, PackedByteArray([17, 0, 255, 128, 1]), "and is byte-identical")


func test_apply_refuses_a_non_empty_store_and_changes_nothing() -> void:
	"""Allocate before consume: a refusal leaves BOTH collaborating stores byte-identical."""
	assert_true(_submit(8, 1, PackedByteArray([1])), "a command in the saved world")
	assert_true(_submit_speed(4), "an event in the saved world")
	var decoded: PendingCommands.Record = PendingCommands.Record.new()
	assert_equal(_decode_refusal(_encoded_world(), decoded).code, PendingCommands.REFUSE_NONE,
		"the section decodes")
	var world: Array = _fresh_world()
	var commands: CommandsScript = world[2] as CommandsScript
	var scheduler: SchedulerEventsScript = world[3] as SchedulerEventsScript
	var occupant: CommandsScript.Command = CommandsScript.Command.new()
	occupant.kind = 3
	assert_true(commands.submit_into(occupant, CommandsScript.SubmitResult.new()),
		"the target world already holds an edit")
	var before: PackedByteArray = _encode_stores(commands, scheduler)
	assert_equal(_apply_with_barrier(decoded, commands, scheduler, 0).code,
		PendingCommands.REFUSE_STORE_NOT_EMPTY, "apply refuses a non-empty queue")
	assert_equal(_encode_stores(commands, scheduler), before,
		"and both stores are byte-identical afterwards")


func test_apply_refuses_a_tick_the_restored_clock_has_already_completed() -> void:
	"""A command due at or before the restored completed tick would execute late, so it refuses."""
	assert_true(_submit(8, 1, PackedByteArray()), "a command due at tick 1")
	var decoded: PendingCommands.Record = PendingCommands.Record.new()
	assert_equal(_decode_refusal(_encoded_world(), decoded).code, PendingCommands.REFUSE_NONE,
		"the section decodes")
	var world: Array = _fresh_world()
	var commands: CommandsScript = world[2] as CommandsScript
	var scheduler: SchedulerEventsScript = world[3] as SchedulerEventsScript
	assert_true((world[0] as SimClockScript).restore_runtime(9, 0, 1, 0, 0, 0, 0, 0, 0, 0),
		"the target clock is restored past the saved tick")
	var before: PackedByteArray = _encode_stores(commands, scheduler)
	assert_equal(_apply_with_barrier(decoded, commands, scheduler, 9).code,
		PendingCommands.REFUSE_STORE_REFUSED, "apply refuses the stale record")
	assert_equal(_encode_stores(commands, scheduler), before,
		"and both stores are byte-identical afterwards")


func test_apply_refuses_a_boundary_the_scheduler_owner_rejects() -> void:
	"""`restore_extension()`'s "pending boundary == saved completed tick" gate runs before writes."""
	assert_true(_submit_speed(2), "a pending event at boundary 0")
	assert_true(_submit(8, 1, PackedByteArray()), "and a pending command")
	var decoded: PendingCommands.Record = PendingCommands.Record.new()
	assert_equal(_decode_refusal(_encoded_world(), decoded).code, PendingCommands.REFUSE_NONE,
		"the section decodes")
	var world: Array = _fresh_world()
	var commands: CommandsScript = world[2] as CommandsScript
	var scheduler: SchedulerEventsScript = world[3] as SchedulerEventsScript
	assert_true((world[0] as SimClockScript).restore_runtime(4, 0, 1, 0, 0, 0, 0, 0, 0, 0),
		"target clock matches the supplied saved tick")
	decoded.execute_tick[0] = 5
	var before: PackedByteArray = _encode_stores(commands, scheduler)
	assert_equal(_apply_with_barrier(decoded, commands, scheduler, 4).code,
		PendingCommands.REFUSE_STORE_REFUSED,
		"a saved completed tick the pending events do not match refuses")
	assert_equal(_encode_stores(commands, scheduler), before,
		"and neither store was touched, not even the one this module would install first")


func test_apply_passes_through_the_load_barrier() -> void:
	"""Restore is not a command (RESTORE-R01): the install writes through a held barrier."""
	assert_true(_submit(8, 1, PackedByteArray([2])), "a command in the saved world")
	assert_true(_submit_speed(4), "an event in the saved world")
	var decoded: PendingCommands.Record = PendingCommands.Record.new()
	var saved: PackedByteArray = _encoded_world()
	assert_equal(_decode_refusal(saved, decoded).code, PendingCommands.REFUSE_NONE,
		"the section decodes")
	var world: Array = _fresh_world()
	var clock: SimClockScript = world[0] as SimClockScript
	var grant: SimClockScript.LoadBarrierGrant = clock.acquire_load_barrier()
	assert_true(grant.is_ok(), "the barrier is raised for this load")
	assert_true(clock.is_load_barrier_held(), "and it is held")
	assert_equal(_apply_with_barrier(decoded, world[2] as CommandsScript,
		world[3] as SchedulerEventsScript, 0).code, PendingCommands.REFUSE_NONE,
		"the install writes through the barrier it was raised for")
	assert_equal(_encode_stores(world[2] as CommandsScript, world[3] as SchedulerEventsScript),
		saved, "and reproduces the saved bytes exactly")


func test_agrees_with_stores_cross_checks_the_public_readers() -> void:
	"""An independent comparison through the owners' public readers, not through capture again."""
	assert_true(_submit(8, 1, PackedByteArray([1, 2])), "one pending command")
	assert_true(_submit_speed(4), "one pending event")
	var record: PendingCommands.Record = _capture()
	assert_equal(PendingCommands.agrees_with_stores(record, _commands, _scheduler).code,
		PendingCommands.REFUSE_NONE, "a fresh capture agrees with its own stores")
	var world: Array = _fresh_world()
	assert_equal(PendingCommands.agrees_with_stores(record, world[2] as CommandsScript,
		world[3] as SchedulerEventsScript).code, PendingCommands.REFUSE_STORE_REFUSED,
		"and disagrees with an empty pair")


# --- BLOCKER P2: the arena rebuild gate ---------------------------------------------------------------------

func test_arena_rebuild_gate_accepts_a_contiguous_arena() -> void:
	"""The normal world: pending payloads tile the arena from offset 0 in canonical order."""
	assert_true(_submit(8, 1, PackedByteArray([1, 2, 3])), "the first command")
	assert_true(_submit(8, 2, PackedByteArray([4])), "the second command")
	var record: PendingCommands.Record = _capture()
	assert_equal(record.payload_offset[0], 0, "the first pending payload starts the arena")
	assert_equal(record.payload_offset[1], 3, "the second follows it exactly")
	assert_equal(record.payload_used, 4, "and the cursor sits at their sum")
	assert_equal(PendingCommands.arena_rebuild_refusal(record).code, PendingCommands.REFUSE_NONE,
		"a contiguous arena is rebuildable through admit_stamped_into()")


func test_arena_restore_accepts_a_dead_prefix_and_retains_offsets() -> void:
	"""A zero prefix is consumed arena space, not a reason to compact live bytes."""
	assert_true(_submit(8, 1, PackedByteArray([1, 2, 3])), "fixture command")
	var record: PendingCommands.Record = _capture()
	record.payload.fill(0)
	record.payload[1] = 1
	record.payload[2] = 2
	record.payload[3] = 3
	record.payload_offset[0] = 1
	record.payload_used = 4
	_assert_arena_round_trip(record)


func test_arena_restore_accepts_offsets_permuted_relative_to_keys() -> void:
	"""Allocation order and canonical key order are independent."""
	assert_true(_submit(8, 1, PackedByteArray([1, 2, 3])), "first command")
	assert_true(_submit(8, 2, PackedByteArray([4, 5])), "second command")
	var record: PendingCommands.Record = _capture()
	record.payload_offset[0] = 2
	record.payload_offset[1] = 0
	_assert_arena_round_trip(record)


func test_arena_restore_accepts_a_zero_dead_tail_without_compaction() -> void:
	"""The highwater can exceed the final live span and must survive restore."""
	assert_true(_submit(8, 1, PackedByteArray([1, 2, 3])), "fixture command")
	var record: PendingCommands.Record = _capture()
	record.payload_used = 9
	_assert_arena_round_trip(record)


func _assert_arena_round_trip(record: PendingCommands.Record) -> void:
	"""Exercise real encoding, decoding and target installation for each arena shape."""
	assert_true(PendingCommands.arena_rebuild_refusal(record).is_ok(), "consistent arena accepted")
	var bytes: PackedByteArray = _encode(record)
	var decoded: PendingCommands.Record = PendingCommands.Record.new()
	assert_true(_decode_refusal(bytes, decoded).is_ok(), "wire decodes")
	var world: Array = _fresh_world()
	assert_true(_apply_with_barrier(decoded, world[2], world[3], 0).is_ok(), "exact owner install")
	assert_equal(_encode_stores(world[2], world[3]), bytes, "exact offsets, payload and highwater")


func _apply_with_barrier(record: PendingCommands.Record, commands: CommandsScript,
		scheduler: SchedulerEventsScript, saved_tick: int) -> SaveHeader.Refusal:
	"""Give historical codec fixtures a real barrier, releasing only this helper's token."""
	var token: SimClockScript.LoadBarrier = null
	if not commands.clock().is_load_barrier_held():
		var grant: SimClockScript.LoadBarrierGrant = commands.clock().acquire_load_barrier()
		assert_true(grant.is_ok(), "apply fixture obtains barrier")
		token = grant.token
	var refusal: SaveHeader.Refusal = PendingCommands.apply(record, commands, scheduler, saved_tick)
	if token != null:
		assert_true(token.release(), "helper releases its own token")
	return refusal


# --- housekeeping -----------------------------------------------------------------------------------------

func test_source_contains_no_float() -> void:
	"""ARCH-AUTH-002: integer authoritative state. A float in this codec would be a defect."""
	var source: FileAccess = FileAccess.open(
		"res://scripts/core/save_section_pending_commands.gd", FileAccess.READ)
	assert_not_null(source, "the module source must be readable")
	var text: String = source.get_as_text()
	source.close()
	var lines: PackedStringArray = text.split("\n")
	var offenders: int = 0
	for line: String in lines:
		if line.begins_with("#") or line.strip_edges().begins_with("##"):
			continue
		if line.contains(" float") or line.contains("float)") or line.contains(": float"):
			offenders += 1
	assert_equal(offenders, 0, "no float declaration may appear in this module")


func test_record_clear_restores_the_declared_unused_values() -> void:
	"""SAVE-LAYOUT-R01: "Use zero only where the owner declares zero"."""
	var record: PendingCommands.Record = PendingCommands.Record.new()
	assert_equal(record.target_slot[0], EntityDirectoryScript.NULL_SLOT,
		"an unused target slot is -1, matching commands.gd::clear()")
	assert_equal(record.target_generation[0], EntityDirectoryScript.NULL_GENERATION,
		"an unused target generation is 0")
	assert_equal(record.scheduler_last_drained_boundary, SchedulerEventsScript.NO_PRIOR_DRAIN,
		"a queue that has never drained reports -1, not 0")
	assert_equal(record.payload.size(), CommandsScript.PAYLOAD_ARENA_BYTES,
		"the arena column is allocated at full capacity once")
	assert_equal(record.execute_tick.size(), CommandsScript.QUEUE_CAPACITY,
		"the economic columns are allocated at ring capacity once")
	assert_equal(record.boundary_tick.size(), SchedulerEventsScript.QUEUE_CAPACITY,
		"the scheduler columns are allocated at ring capacity once")
