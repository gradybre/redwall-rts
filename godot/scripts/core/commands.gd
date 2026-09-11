extends RefCounted
## ARCH-CMD-001/003 and §8.1's economic command queue: the first thing in this project that can
## carry a player's intent into the simulation.
##
## Four job producers exist in `job_planner.gd` and NOTHING CAN CALL THEM. This module is the
## transport that will: an ordered, finite, next-tick queue of player edits with a compiled kind
## domain, generation-checked targets and a bounded payload arena. It is TRANSPORT ONLY -- see
## "WHAT THIS DELIBERATELY DOES NOT DO" below before extending it.
##
## ---------------------------------------------------------------------------------------
## THE THREE CONTRACTS IMPLEMENTED HERE, verbatim from `docs/systems_architecture.md`:
##
##   ARCH-CMD-001  "Settlement command records use the field layout in §8 and sort by
##                  (execute_tick,player_id,sequence_high_unsigned,sequence_low_unsigned). This
##                  preserves the crowd's player/64-bit-sequence ordering within a tick. Player ID
##                  is 0 in release 1. Assign each submitted command execute_tick=completed_tick+1;
##                  paused edits receive the same next tick, increasing sequence. Their
##                  ghosts/pending rows are presentation only. Save pending commands when paused
##                  without consuming them."
##
##   ARCH-CMD-003  "Command kinds [NEW sorted ASCII domain] are ACCEPT_CANDIDATES, ... UPGRADE.
##                  Compile IDs from this exact list; reject unknown kinds. Kind-specific payloads
##                  use the original component field types, count first followed by
##                  owner-ID-sorted rows; all IDs must validate before committing any member of a
##                  group."
##
##   §8.1          The 64-byte record table, "a 4096-command in-memory queue plus a 1048576-byte
##                  payload arena", and "Queue overflow refuses additional edits with an explicit
##                  UI error; accepted commands are never dropped."
##
## ---------------------------------------------------------------------------------------
## THE SEQUENCE COMPARISON IS UNSIGNED, AND THAT IS THE WHOLE POINT OF `compare_key_parts()`.
## §8.1 types `sequence_low` and `sequence_high` as "u32 bits", and this store keeps them in
## `PackedInt32Array` columns because that is what a 4-byte packed column is. A 64-bit session
## counter crossing 2147483648 therefore stores a NEGATIVE i32, and a signed comparison puts
## sequence 0x80000000 BEFORE 0x7fffffff -- silently reordering two commands the player issued in
## the opposite order, with no error anywhere. Every comparison here masks with 0xffffffff first,
## exactly as ARCH-RNG-001 already requires for stored xorshift state. `test_commands.gd` fails
## under a signed comparison by value, not by assertion text.
##
## ORDER IS A RING INDEX OVER FIXED ROWS, AND `_order` IS ALWAYS A PERMUTATION OF 0..4095.
## Positions `_head .. _head+_count-1` (modulo 4096) name the queued rows in ARCH-CMD-001 order;
## the remaining positions hold the free rows. Insert takes the row sitting at the first free
## position and shifts the tail right; pop advances `_head`, which leaves the freed row in what has
## become the last free position without touching it. So no free list, no tombstones, and no row is
## ever handed out twice. This costs 16384 bytes (4096 i32) beyond §2.3's already-budgeted 262144,
## added to the ledger under decision 0042.
##
## THE RECORD COLUMNS ARE EXACTLY §8.1's 64 BYTES: one i64 (8) plus fourteen i32 (56). The layout
## is the SERIALIZATION contract -- `encode_record_into()` and `decode_record_into()` are its only
## implementation, offsets are named constants, and `test_commands.gd` asserts every one of them
## against hard-coded literals so that renaming a constant cannot move a field unnoticed.
##
## ---------------------------------------------------------------------------------------
## WHAT THIS DELIBERATELY DOES NOT DO. Each is somebody's declared work, not an oversight:
##
##   * ARCH-CMD-002's SPEED/PAUSE SCHEDULER EVENTS ARE A SEPARATE QUEUE AND ARE NOT HERE. They now
##     EXIST, in `scripts/core/scheduler_events.gd`, which implements task 04.1's completed
##     amendment R07-SCHED-001 (decision 0054) with its own 32-byte record, its own 64-bit
##     sequence space and its own boundary pump. Nothing about THIS file changed for it: the
##     speed/pause keys are still kept OUT of the CommandKind catalog on 04.1's explicit
##     instruction, because inserting one would renumber the 24 stable IDs, and no economic record
##     carries a scheduler event. **BLOCKER U2 IS NO LONGER PARTLY CLOSED BY THIS FILE ALONE**;
##     see `sim_clock.gd`'s U2 header for what closed and what is still blocked on a save module.
##
##   * NO PRODUCER IS CALLED. This is admission and ordering, not dispatch. `job_planner.gd` is not
##     preloaded and not touched; binding accepted commands to its entry points is 04.2/04.4's
##     named handoff through ARCH-SYS-002/009. A drained command is handed back to the caller.
##
##   * NO PER-KIND PAYLOAD SCHEMA. §8.1 says payloads "contain full selection ID lists, schedule
##     bytes, zone tiles, recipe orders, or sanitized aliases; the payload schema is selected by
##     the command kind" -- and NOWHERE states any of those 24 schemas. So payload bytes are
##     opaque here and only their SPAN is validated. The one shape ARCH-CMD-003 does describe,
##     "count first followed by owner-ID-sorted rows", is implemented as `submit_id_group_into()`
##     from the original component field types (EntityRef = two i32, so 4-byte count + 8-byte
##     rows). WHICH KINDS CARRY ONE IS UNSPECIFIED, so the form is chosen by the caller rather
##     than derived from the kind; deriving it would be inventing 24 schemas. 04.2 owns them.
##
##   * `goal_x`/`goal_z` UNITS ARE UNRESOLVED. §8.1 types them i32 and says nothing more. GDD §4.2
##     positions are 1/1024 m and ARCH-PATH-001 cells are 1/2 m; §8.1 does not say which a command
##     carries, so only the i32 range is checked and NO map bound is asserted. Naming the unit is a
##     specification change, not a runtime choice.
##
##   * `flags` HAS NO DEFINED BIT ANYWHERE, so a nonzero value is REFUSED rather than stored. An
##     accepted undefined bit would be a semantic this file invented and the drain would ignore.
##     This is the same treatment §8.1 already gives `reserved_zero`, and it narrows the day a
##     flag is specified. INTERPRETATION, recorded as one (decision 0042).
##
##   * PERSISTENCE IS BLOCKED, NOT IMPLEMENTED. "Save pending commands when paused without
##     consuming them" holds in-process: only a tick drains, and no tick runs while paused. There
##     is NO SAVE MODULE in this repository, so a paused queue cannot yet survive a process
##     restart. `encode_record_into()` produces exactly the bytes such a writer needs, and is
##     unwired. Task 09 owns the codec; 04.1 owns the pending-command save subsection.
##
## ---------------------------------------------------------------------------------------
## PAYLOAD ARENA RECLAMATION IS BUMP-AND-RESET, AND ITS LIMIT IS STATED. §8.1 budgets 1048576
## bytes and defines no allocator. This one bumps a cursor and resets it the moment the queue is
## empty (lazily, inside `_allocate_payload()`), which is exhaustive for the normal cycle: every
## accepted command is due at `completed_tick+1`, so one drain empties the queue and returns the
## whole arena. It NEVER compacts and never partially frees, so a queue that is continuously
## non-empty across more than 1048576 bytes of payload REFUSES with COMMAND_PAYLOAD_ARENA_FULL
## rather than overwriting a pending command's bytes. A drained command's payload stays readable
## until the next accepted submission -- read it inside the drain loop, which is where a tick uses
## it. INTERPRETATION, recorded in decision 0042.
##
## ALLOCATE BEFORE CONSUME (decision 0024), WHICH IS WHAT MAKES A GROUP ATOMIC. Both group forms
## validate every member -- queue room, sequence room, arena room, envelope, and every EntityRef
## against the directory's generation -- BEFORE one byte is written. A group with one invalid
## member leaves the queue byte-identical: same rows, same order index, same arena, same counters,
## same sequence. That is asserted by comparing encoded bytes, not by inspecting a flag.

const Catalog := preload("res://scripts/core/catalog.gd")
const EntityDirectory := preload("res://scripts/core/entity_directory.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")

# --- §8.1's command record: offsets, stride, and the two budgeted capacities ---------------------

## Every offset is §8.1's own, in its own order. Stride is that table's [DERIVED sum].
const OFFSET_EXECUTE_TICK: int = 0
const OFFSET_PLAYER_ID: int = 8
const OFFSET_SEQUENCE_LOW: int = 12
const OFFSET_SEQUENCE_HIGH: int = 16
const OFFSET_KIND: int = 20
const OFFSET_TARGET_SLOT: int = 24
const OFFSET_TARGET_GENERATION: int = 28
const OFFSET_GOAL_X: int = 32
const OFFSET_GOAL_Z: int = 36
const OFFSET_ARG0: int = 40
const OFFSET_ARG1: int = 44
const OFFSET_PAYLOAD_OFFSET: int = 48
const OFFSET_PAYLOAD_LENGTH: int = 52
const OFFSET_FLAGS: int = 56
const OFFSET_RESERVED_ZERO: int = 60
const RECORD_BYTES: int = 64
const FIELD_BYTES: int = 4
const TICK_FIELD_BYTES: int = 8

## §8.1: "a 4096-command in-memory queue plus a 1048576-byte payload arena". §2.3's ledger row
## "Command queue | 4096 | 64 | 262144" is these two numbers multiplied.
const QUEUE_CAPACITY: int = 4096
const PAYLOAD_ARENA_BYTES: int = 1048576

## ARCH-CMD-001: "Player ID is 0 in release 1 [NEW]." Any other id is refused, never remapped.
const RELEASE_ONE_PLAYER_ID: int = 0

## u32 bits held in an i32 column, read back the way ARCH-RNG-001 reads stored xorshift state.
const U32_MASK: int = 0xffffffff
const U32_MAX: int = 4294967295
const U32_SIGN_BIT: int = 2147483648
const U32_MODULUS: int = 4294967296

## ARCH-CMD-003's "count first followed by owner-ID-sorted rows", in the original component field
## types: `count` is one i32 and each row is an EntityRef, which GDD §4.2 defines as two i32.
const ID_GROUP_COUNT_BYTES: int = 4
const ID_GROUP_ROW_BYTES: int = 8
const ID_GROUP_MAX_ROWS: int = (PAYLOAD_ARENA_BYTES - ID_GROUP_COUNT_BYTES) / ID_GROUP_ROW_BYTES

# --- refusal codes (StringName; this module never returns a sentinel to signal failure) ----------

const REFUSE_NONE: StringName = &""
const REFUSE_QUEUE_FULL: StringName = &"COMMAND_QUEUE_FULL"
const REFUSE_QUEUE_NOT_EMPTY: StringName = &"COMMAND_QUEUE_NOT_EMPTY"
const REFUSE_NO_CLOCK: StringName = &"COMMAND_NO_CLOCK"
const REFUSE_UNKNOWN_KIND: StringName = &"COMMAND_UNKNOWN_KIND"
const REFUSE_UNKNOWN_PLAYER: StringName = &"COMMAND_UNKNOWN_PLAYER"
const REFUSE_TARGET_MALFORMED: StringName = &"COMMAND_TARGET_MALFORMED"
const REFUSE_TARGET_INVALID: StringName = &"COMMAND_TARGET_INVALID"
const REFUSE_FIELD_RANGE: StringName = &"COMMAND_FIELD_RANGE"
const REFUSE_FLAGS_UNDEFINED: StringName = &"COMMAND_FLAGS_UNDEFINED"
const REFUSE_RESERVED_NONZERO: StringName = &"COMMAND_RESERVED_NONZERO"
const REFUSE_PAYLOAD_ARENA_FULL: StringName = &"COMMAND_PAYLOAD_ARENA_FULL"
const REFUSE_PAYLOAD_SPAN: StringName = &"COMMAND_PAYLOAD_SPAN"
const REFUSE_PAYLOAD_CONFLICT: StringName = &"COMMAND_PAYLOAD_CONFLICT"
const REFUSE_SEQUENCE_EXHAUSTED: StringName = &"COMMAND_SEQUENCE_EXHAUSTED"
const REFUSE_SEQUENCE_RANGE: StringName = &"COMMAND_SEQUENCE_RANGE"
const REFUSE_DUPLICATE_KEY: StringName = &"COMMAND_DUPLICATE_KEY"
const REFUSE_TICK_IN_PAST: StringName = &"COMMAND_TICK_IN_PAST"
const REFUSE_EMPTY_GROUP: StringName = &"COMMAND_EMPTY_GROUP"
const REFUSE_GROUP_MEMBER_TYPE: StringName = &"COMMAND_GROUP_MEMBER_TYPE"
const REFUSE_ID_GROUP_SHAPE: StringName = &"COMMAND_ID_GROUP_SHAPE"
const REFUSE_ID_GROUP_UNSORTED: StringName = &"COMMAND_ID_GROUP_UNSORTED"
const REFUSE_ID_GROUP_MEMBER: StringName = &"COMMAND_ID_GROUP_MEMBER_INVALID"
const REFUSE_POSITION: StringName = &"COMMAND_POSITION_OUT_OF_RANGE"
const REFUSE_BUFFER_TOO_SMALL: StringName = &"COMMAND_BUFFER_TOO_SMALL"


class Command:
	"""One §8.1 command record, caller-owned and reused: the submission envelope and the drain
	output are the same shape.

	On submission the caller fills the intent fields -- `kind`, `target_slot`,
	`target_generation`, `goal_x`, `goal_z`, `arg0`, `arg1`, `flags`, `reserved_zero` and
	`payload`. The QUEUE is the only thing that stamps `execute_tick`, `player_id`, the two
	sequence halves and the payload span, so those four are overwritten by `submit_into()` and a
	stale value left on a reused envelope cannot become a key. `admit_stamped_into()` is the one
	entry point that reads them, because a replay stream carries its own envelope.

	`sequence_low` and `sequence_high` hold u32 BITS in an i32 field, so 0x80000000 reads back as
	-2147483648. Use `sequence_low_unsigned()`/`sequence_high_unsigned()` for comparison.
	"""
	var execute_tick: int = 0
	var player_id: int = 0
	var sequence_low: int = 0
	var sequence_high: int = 0
	var kind: int = 0
	var target_slot: int = -1
	var target_generation: int = 0
	var goal_x: int = 0
	var goal_z: int = 0
	var arg0: int = 0
	var arg1: int = 0
	var payload_offset: int = 0
	var payload_length: int = 0
	var flags: int = 0
	var reserved_zero: int = 0
	var payload: PackedByteArray = PackedByteArray()

	func sequence_low_unsigned() -> int:
		"""The low sequence word as its unsigned value, the way ARCH-CMD-001 orders it."""
		return sequence_low & 0xffffffff

	func sequence_high_unsigned() -> int:
		"""The high sequence word as its unsigned value, the way ARCH-CMD-001 orders it."""
		return sequence_high & 0xffffffff

	func target_ref() -> Vector2i:
		"""This command's target as an EntityRef; `(-1, 0)` when it names none."""
		return Vector2i(target_slot, target_generation)

	func reset() -> void:
		"""Return every field to the empty envelope so one owned instance can be reused."""
		execute_tick = 0
		player_id = 0
		sequence_low = 0
		sequence_high = 0
		kind = 0
		target_slot = -1
		target_generation = 0
		goal_x = 0
		goal_z = 0
		arg0 = 0
		arg1 = 0
		payload_offset = 0
		payload_length = 0
		flags = 0
		reserved_zero = 0
		payload.clear()


class SubmitResult:
	"""Outcome of one admission attempt, caller-owned and reused.

	`.ok` MUST be inspected first. On refusal `accepted` is 0 -- nothing was queued, not even
	partially -- and `member` is the index of the group member that failed, which is 0 for a
	single command and meaningless on success. Every entry point clears the member first, so a
	previous group's failing index can never be reported against a later single command.
	"""
	var ok: bool = false
	var error: StringName = &""
	var accepted: int = 0
	var member: int = 0

	func fill(p_ok: bool, p_error: StringName, p_accepted: int, p_member: int) -> void:
		"""Overwrite this result in place, so an admission attempt allocates nothing."""
		ok = p_ok
		error = p_error
		accepted = p_accepted
		member = p_member


# --- collaborating stores ------------------------------------------------------------------------

var _clock: SimClock = null
var _directory: EntityDirectory = null

# --- §8.1's record columns: one i64 plus fourteen i32 = exactly 64 bytes per row ------------------

var _execute_tick: PackedInt64Array = PackedInt64Array()
var _player_id: PackedInt32Array = PackedInt32Array()
var _sequence_low: PackedInt32Array = PackedInt32Array()
var _sequence_high: PackedInt32Array = PackedInt32Array()
var _kind: PackedInt32Array = PackedInt32Array()
var _target_slot: PackedInt32Array = PackedInt32Array()
var _target_generation: PackedInt32Array = PackedInt32Array()
var _goal_x: PackedInt32Array = PackedInt32Array()
var _goal_z: PackedInt32Array = PackedInt32Array()
var _arg0: PackedInt32Array = PackedInt32Array()
var _arg1: PackedInt32Array = PackedInt32Array()
var _payload_offset: PackedInt32Array = PackedInt32Array()
var _payload_length: PackedInt32Array = PackedInt32Array()
var _flags: PackedInt32Array = PackedInt32Array()
var _reserved_zero: PackedInt32Array = PackedInt32Array()

## The ARCH-CMD-001 order: a ring of positions over the rows above, always a permutation of
## 0..QUEUE_CAPACITY-1. [decision 0042; +16384 bytes in §2.3]
var _order: PackedInt32Array = PackedInt32Array()
## §8.1's 1048576-byte payload arena.
var _payload: PackedByteArray = PackedByteArray()

# --- queue state ---------------------------------------------------------------------------------

var _head: int = 0
var _count: int = 0
var _payload_used: int = 0
var _next_sequence_high: int = 0
var _next_sequence_low: int = 0
var _kind_count: int = 0
var _last_refusal: StringName = REFUSE_NONE
var _refused_member: int = 0
var _accepted_count: int = 0
var _refused_count: int = 0
var _drained_count: int = 0

# --- scratch (not simulation state) --------------------------------------------------------------

var _math: IntMath.IntResult = IntMath.IntResult.new()
## One owned empty reference list, so the commit path's "no ID group" case allocates nothing.
var _no_refs: PackedInt32Array = PackedInt32Array()
## One owned record used by `encode_record_into()`, so encoding a queued row allocates nothing.
var _scratch: Command = Command.new()


func _init(p_clock: SimClock = null, p_directory: EntityDirectory = null) -> void:
	"""Bind the clock and directory, prove the borrowed contracts, and allocate the columns once.

	Passing existing stores shares them. Passing nothing builds a private consistent pair, which is
	what a unit fixture wants: the clock supplies `completed_tick+1` and the directory is what a
	target EntityRef is validated against, so a second directory would validate against the wrong
	generations.
	"""
	_clock = p_clock if p_clock != null else SimClock.new()
	_directory = p_directory if p_directory != null else EntityDirectory.new()
	_kind_count = Catalog.COMMAND_KIND.size()
	_assert_contracts()
	_allocate_columns()
	clear()


func _assert_contracts() -> void:
	"""Prove §8.1's stride, the ledger row and ARCH-CMD-003's compiled domain before any use."""
	var verified: Catalog.DomainResult = Catalog.verify_compiled_enum(Catalog.COMMAND_KIND_DOMAIN)
	assert(verified.ok, "ARCH-CMD-003's kinds must be the ASCII compilation of their own keys")
	assert(_kind_count == verified.ids.size(), "every compiled kind must be in the table")
	assert(OFFSET_RESERVED_ZERO + FIELD_BYTES == RECORD_BYTES,
		"§8.1's last field must end exactly at the 64-byte stride")
	assert(TICK_FIELD_BYTES + 14 * FIELD_BYTES == RECORD_BYTES,
		"the record is one i64 tick plus fourteen i32 fields")
	assert(QUEUE_CAPACITY * RECORD_BYTES == 262144,
		"§2.3's command queue row is 4096 records of 64 bytes")


func _allocate_columns() -> void:
	"""Size every packed column exactly once, per ARCH-MEM-001. Never called again."""
	_execute_tick.resize(QUEUE_CAPACITY)
	for column: PackedInt32Array in [_player_id, _sequence_low, _sequence_high, _kind,
			_target_slot, _target_generation, _goal_x, _goal_z, _arg0, _arg1, _payload_offset,
			_payload_length, _flags, _reserved_zero, _order]:
		column.resize(QUEUE_CAPACITY)
	_payload.resize(PAYLOAD_ARENA_BYTES)


func clear() -> void:
	"""Return the queue, the arena and the session sequence to their initial state.

	This is world initialization, not a drain: it discards pending commands and resets the
	sequence, so nothing that survives a save may call it.
	"""
	for index: int in QUEUE_CAPACITY:
		_order[index] = index
	_execute_tick.fill(0)
	for column: PackedInt32Array in [_player_id, _sequence_low, _sequence_high, _kind, _goal_x,
			_goal_z, _arg0, _arg1, _payload_offset, _payload_length, _flags, _reserved_zero]:
		column.fill(0)
	_target_slot.fill(EntityDirectory.NULL_SLOT)
	_target_generation.fill(EntityDirectory.NULL_GENERATION)
	_payload.fill(0)
	_head = 0
	_count = 0
	_payload_used = 0
	_next_sequence_high = 0
	_next_sequence_low = 0
	_last_refusal = REFUSE_NONE
	_refused_member = 0
	_accepted_count = 0
	_refused_count = 0
	_drained_count = 0


# --- ARCH-CMD-001's ordering key ------------------------------------------------------------------

static func compare_key_parts(a_tick: int, a_player: int, a_high: int, a_low: int,
		b_tick: int, b_player: int, b_high: int, b_low: int) -> int:
	"""ARCH-CMD-001's `(execute_tick, player_id, sequence_high_unsigned, sequence_low_unsigned)`.

	Returns -1, 0 or 1. The tick is a signed i64 and the player is a signed i32; BOTH SEQUENCE
	WORDS ARE MASKED TO THEIR UNSIGNED VALUE FIRST, because they are u32 bits stored in an i32
	field and a signed comparison would order 0x80000000 before 0x7fffffff.
	"""
	if a_tick != b_tick:
		return -1 if a_tick < b_tick else 1
	if a_player != b_player:
		return -1 if a_player < b_player else 1
	var high_a: int = a_high & U32_MASK
	var high_b: int = b_high & U32_MASK
	if high_a != high_b:
		return -1 if high_a < high_b else 1
	var low_a: int = a_low & U32_MASK
	var low_b: int = b_low & U32_MASK
	if low_a != low_b:
		return -1 if low_a < low_b else 1
	return 0


static func compare_keys(a: Command, b: Command) -> int:
	"""Compare two records by ARCH-CMD-001's key. Delegates, so there is one comparison here."""
	return compare_key_parts(a.execute_tick, a.player_id, a.sequence_high, a.sequence_low,
		b.execute_tick, b.player_id, b.sequence_high, b.sequence_low)


static func to_int32_bits(value: int) -> int:
	"""The i32 two's-complement spelling of a u32 bit pattern, so a packed i32 column stores it."""
	var bits: int = value & U32_MASK
	return bits - U32_MODULUS if bits >= U32_SIGN_BIT else bits


static func to_uint32(value: int) -> int:
	"""The unsigned value of a u32 bit pattern held in an i32 field."""
	return value & U32_MASK


func _compare_row(row: int, tick: int, player: int, high: int, low: int) -> int:
	"""Compare stored row `row` against a loose key, through the one comparison above."""
	return compare_key_parts(_execute_tick[row], _player_id[row], _sequence_high[row],
		_sequence_low[row], tick, player, high, low)


func _lower_bound(tick: int, player: int, high: int, low: int) -> int:
	"""The first queue position whose key is not less than the given key, by binary search."""
	var lower: int = 0
	var upper: int = _count
	while lower < upper:
		var middle: int = (lower + upper) / 2
		if _compare_row(_row_at(middle), tick, player, high, low) < 0:
			lower = middle + 1
		else:
			upper = middle
	return lower


func _has_key(tick: int, player: int, high: int, low: int) -> bool:
	"""True when a queued command already carries exactly this ordering key."""
	var position: int = _lower_bound(tick, player, high, low)
	if position >= _count:
		return false
	return _compare_row(_row_at(position), tick, player, high, low) == 0


func _row_at(position: int) -> int:
	"""The storage row holding the command at queue position `position`."""
	return _order[(_head + position) % QUEUE_CAPACITY]


# --- admission -----------------------------------------------------------------------------------

func submit_into(command: Command, out: SubmitResult) -> bool:
	"""Queue one player edit for `completed_tick+1`, stamping ARCH-CMD-001's whole envelope.

	The caller's `execute_tick`, `player_id` and sequence halves are IGNORED and overwritten: the
	queue is the only stamper, so a reused envelope cannot smuggle a stale key. Returns false and
	fills `out` with the refusal on any failure, having changed nothing.
	"""
	_refused_member = 0
	var tick: int = next_execute_tick()
	var length: int = command.payload.size()
	var refusal: StringName = _admission_refusal(command, 1, length)
	if refusal == REFUSE_NONE:
		refusal = _stamped_key_refusal(tick, 1)
	if refusal != REFUSE_NONE:
		return _refuse(out, refusal)
	_commit_next(command, tick, length, _no_refs)
	return _accept(out, 1)


func _commit_next(command: Command, tick: int, length: int, refs: PackedInt32Array) -> void:
	"""Commit one validated command under the next session sequence and consume that sequence."""
	_commit_stamped(command, tick, RELEASE_ONE_PLAYER_ID, to_int32_bits(_next_sequence_high),
		to_int32_bits(_next_sequence_low), length, refs)
	_advance_sequence()


func _stamped_key_refusal(tick: int, members: int) -> StringName:
	"""Refuse when any sequence the next `members` stamps would take is already queued at `tick`.

	Reachable: a replay record admitted through `admit_stamped_into()` carries its own sequence,
	which the session counter knows nothing about, so the very next stamped edit can collide.
	"""
	for step: int in members:
		var low: int = _next_sequence_low + step
		var high: int = _next_sequence_high + low / U32_MODULUS
		if _has_key(tick, RELEASE_ONE_PLAYER_ID, to_int32_bits(high),
				to_int32_bits(low % U32_MODULUS)):
			return REFUSE_DUPLICATE_KEY
	return REFUSE_NONE


func submit_group_into(members: Array, out: SubmitResult) -> bool:
	"""Queue several player edits atomically: every member validates, or none is written.

	Decision 0024's allocate-before-consume at the queue layer. Members keep their submitted order,
	because they share one `execute_tick` and take consecutive sequence numbers. On refusal the
	queue is byte-identical to what it was, and `out.member` names the member that failed.
	"""
	var tick: int = next_execute_tick()
	var refusal: StringName = _group_refusal(members)
	if refusal == REFUSE_NONE:
		refusal = _stamped_key_refusal(tick, members.size())
	if refusal != REFUSE_NONE:
		return _refuse(out, refusal)
	for index: int in members.size():
		var command: Command = members[index] as Command
		_commit_next(command, tick, command.payload.size(), _no_refs)
	return _accept(out, members.size())


func submit_id_group_into(command: Command, refs: PackedInt32Array, out: SubmitResult) -> bool:
	"""Queue one command whose payload is ARCH-CMD-003's count-prefixed, owner-ID-sorted ID rows.

	`refs` is flat `(slot, generation)` pairs. EVERY ID MUST VALIDATE BEFORE ANY MEMBER IS
	COMMITTED, so one stale generation refuses the whole command and writes nothing. The rows must
	already be sorted by ascending owner slot with no repeat: the canonical order is refused into
	existence rather than silently produced, so two callers cannot disagree about it.
	This form BUILDS the payload, so an envelope that also carries opaque bytes is refused rather
	than having them silently dropped.
	"""
	_refused_member = 0
	var tick: int = next_execute_tick()
	var length: int = ID_GROUP_COUNT_BYTES + (refs.size() / 2) * ID_GROUP_ROW_BYTES
	var refusal: StringName = REFUSE_NONE if command.payload.is_empty() \
		else REFUSE_PAYLOAD_CONFLICT
	if refusal == REFUSE_NONE:
		refusal = id_group_refusal(refs)
	if refusal == REFUSE_NONE:
		refusal = _admission_refusal(command, 1, length)
	if refusal == REFUSE_NONE:
		refusal = _stamped_key_refusal(tick, 1)
	if refusal != REFUSE_NONE:
		return _refuse(out, refusal)
	_commit_next(command, tick, length, refs)
	return _accept(out, 1)


func admit_stamped_into(command: Command, out: SubmitResult) -> bool:
	"""Admit one record that already carries its envelope, as a replay or load stream supplies it.

	This is the entry point that reads `execute_tick`, `player_id` and the sequence halves instead
	of stamping them, so arrival order need not be key order: the record is inserted at its
	ARCH-CMD-001 position. A tick already completed refuses rather than executing late, and a
	repeated key refuses rather than making the order ambiguous. The session sequence counter is
	NOT advanced -- a loader restores it with `restore_sequence()`.
	"""
	_refused_member = 0
	var length: int = command.payload.size()
	var refusal: StringName = _stamped_envelope_refusal(command)
	if refusal == REFUSE_NONE:
		refusal = _admission_refusal(command, 1, length)
	if refusal != REFUSE_NONE:
		return _refuse(out, refusal)
	_commit_stamped(command, command.execute_tick, command.player_id, command.sequence_high,
		command.sequence_low, length, _no_refs)
	return _accept(out, 1)


func _stamped_envelope_refusal(command: Command) -> StringName:
	"""Validate the four envelope fields a stamped record supplies for itself."""
	if command.player_id != RELEASE_ONE_PLAYER_ID:
		return REFUSE_UNKNOWN_PLAYER
	if not IntMath.fits_int32(command.sequence_low) or not IntMath.fits_int32(
			command.sequence_high):
		return REFUSE_SEQUENCE_RANGE
	if command.execute_tick <= _clock.completed_tick():
		return REFUSE_TICK_IN_PAST
	if _has_key(command.execute_tick, command.player_id, command.sequence_high,
			command.sequence_low):
		return REFUSE_DUPLICATE_KEY
	return REFUSE_NONE


func _admission_refusal(command: Command, members: int, payload_bytes: int) -> StringName:
	"""Every capacity and envelope gate, evaluated before anything is written."""
	if _count + members > QUEUE_CAPACITY:
		return REFUSE_QUEUE_FULL
	if not _sequence_room(members):
		return REFUSE_SEQUENCE_EXHAUSTED
	if payload_bytes < 0 or payload_bytes > payload_available():
		return REFUSE_PAYLOAD_ARENA_FULL
	return envelope_refusal(command)


func _group_refusal(members: Array) -> StringName:
	"""Validate a whole group's capacity and every member's envelope, writing nothing.

	Sets `_refused_member` to the failing index so the caller's result can name it.
	"""
	_refused_member = 0
	if members.is_empty():
		return REFUSE_EMPTY_GROUP
	if _count + members.size() > QUEUE_CAPACITY:
		return REFUSE_QUEUE_FULL
	if not _sequence_room(members.size()):
		return REFUSE_SEQUENCE_EXHAUSTED
	var payload_bytes: int = 0
	for index: int in members.size():
		_refused_member = index
		if not (members[index] is Command):
			return REFUSE_GROUP_MEMBER_TYPE
		var command: Command = members[index] as Command
		var refusal: StringName = envelope_refusal(command)
		if refusal != REFUSE_NONE:
			return refusal
		payload_bytes += command.payload.size()
		if payload_bytes > payload_available():
			return REFUSE_PAYLOAD_ARENA_FULL
	_refused_member = 0
	return REFUSE_NONE


func envelope_refusal(command: Command) -> StringName:
	"""Every §8.1 field rule checkable without a per-kind payload schema. REFUSE_NONE when clean.

	`flags` must be zero because no specification defines a bit in it; `reserved_zero` must be zero
	because §8.1 names it so. Both are refusals rather than silent normalizations.
	"""
	if not is_valid_kind(command.kind):
		return REFUSE_UNKNOWN_KIND
	if command.reserved_zero != 0:
		return REFUSE_RESERVED_NONZERO
	if command.flags != 0:
		return REFUSE_FLAGS_UNDEFINED
	if not IntMath.fits_int32(command.goal_x) or not IntMath.fits_int32(command.goal_z):
		return REFUSE_FIELD_RANGE
	if not IntMath.fits_int32(command.arg0) or not IntMath.fits_int32(command.arg1):
		return REFUSE_FIELD_RANGE
	return target_refusal(command.target_slot, command.target_generation)


func target_refusal(slot: int, generation: int) -> StringName:
	"""Validate one target EntityRef against the directory's generations, or name the refusal.

	The null reference `(-1, 0)` is accepted as "this command names no entity". WHICH KINDS MUST
	NAME ONE IS UNSPECIFIED -- that is the per-kind schema 04.2 owns -- so it is not decided here.
	"""
	if slot == EntityDirectory.NULL_SLOT:
		if generation == EntityDirectory.NULL_GENERATION:
			return REFUSE_NONE
		return REFUSE_TARGET_MALFORMED
	if slot < 0 or not IntMath.fits_int32(slot) or not IntMath.fits_int32(generation):
		return REFUSE_TARGET_MALFORMED
	if not _directory.is_valid(Vector2i(slot, generation)):
		return REFUSE_TARGET_INVALID
	return REFUSE_NONE


func id_group_refusal(refs: PackedInt32Array) -> StringName:
	"""Validate a whole count-prefixed ID group: shape, owner-ID order, and every generation."""
	if refs.is_empty() or refs.size() % 2 != 0:
		return REFUSE_ID_GROUP_SHAPE
	var count: int = refs.size() / 2
	if count > ID_GROUP_MAX_ROWS:
		return REFUSE_ID_GROUP_SHAPE
	var previous_slot: int = EntityDirectory.NULL_SLOT
	for index: int in count:
		var slot: int = refs[index * 2]
		var generation: int = refs[index * 2 + 1]
		if slot < 0:
			return REFUSE_ID_GROUP_MEMBER
		if slot <= previous_slot:
			return REFUSE_ID_GROUP_UNSORTED
		previous_slot = slot
		if target_refusal(slot, generation) != REFUSE_NONE:
			return REFUSE_ID_GROUP_MEMBER
	return REFUSE_NONE


# --- commit --------------------------------------------------------------------------------------

func _commit_stamped(command: Command, tick: int, player: int, high: int, low: int,
		length: int, refs: PackedInt32Array) -> void:
	"""Write one fully validated command at its ARCH-CMD-001 position. Allocates nothing.

	The payload is reserved BEFORE the row is inserted, because the arena reclaims itself only
	while the queue is empty and inserting first would hide that. A non-empty `refs` writes
	ARCH-CMD-003's ID-group payload instead of copying the envelope's opaque bytes.
	"""
	var offset: int = _allocate_payload(length)
	if refs.is_empty():
		_copy_payload(command, offset, length)
	else:
		_write_id_group(offset, refs)
	var row: int = _insert_at(_lower_bound(tick, player, high, low))
	_write_row(row, command, tick, player, high, low)
	_payload_offset[row] = offset
	_payload_length[row] = length


func _write_row(row: int, command: Command, tick: int, player: int, high: int, low: int) -> void:
	"""Copy one command's intent fields and its stamped envelope into storage row `row`."""
	_execute_tick[row] = tick
	_player_id[row] = player
	_sequence_low[row] = low
	_sequence_high[row] = high
	_kind[row] = command.kind
	_target_slot[row] = command.target_slot
	_target_generation[row] = command.target_generation
	_goal_x[row] = command.goal_x
	_goal_z[row] = command.goal_z
	_arg0[row] = command.arg0
	_arg1[row] = command.arg1
	_flags[row] = command.flags
	_reserved_zero[row] = 0


func _insert_at(position: int) -> int:
	"""Open queue position `position` in the ring order index and return the free row it now holds.

	`_order` stays a permutation of every row: the row taken is the one sitting at the first free
	position, and the tail is shifted right over it.
	"""
	var row: int = _order[(_head + _count) % QUEUE_CAPACITY]
	var index: int = _count
	while index > position:
		_order[(_head + index) % QUEUE_CAPACITY] = _order[(_head + index - 1) % QUEUE_CAPACITY]
		index -= 1
	_order[(_head + position) % QUEUE_CAPACITY] = row
	_count += 1
	return row


func _allocate_payload(length: int) -> int:
	"""Reserve `length` arena bytes and return their offset. The caller has validated the room.

	The whole arena is reclaimed the moment the queue is empty, which is the normal state after
	each tick's drain. There is no partial free and no compaction.
	"""
	if _count == 0:
		_payload_used = 0
	var offset: int = _payload_used
	_payload_used += length
	return offset


func _copy_payload(command: Command, offset: int, length: int) -> void:
	"""Copy a command's payload bytes into the arena at `offset`, byte by byte."""
	for index: int in length:
		_payload[offset + index] = command.payload[index]


func _write_id_group(offset: int, refs: PackedInt32Array) -> void:
	"""Encode ARCH-CMD-003's count-prefixed, owner-ID-sorted EntityRef rows into the arena."""
	var count: int = refs.size() / 2
	_payload.encode_s32(offset, count)
	for index: int in count:
		var row_offset: int = offset + ID_GROUP_COUNT_BYTES + index * ID_GROUP_ROW_BYTES
		_payload.encode_s32(row_offset, refs[index * 2])
		_payload.encode_s32(row_offset + FIELD_BYTES, refs[index * 2 + 1])


func _advance_sequence() -> void:
	"""Step the 64-bit session sequence by one, carrying into the high word. It never wraps."""
	if _next_sequence_low >= U32_MAX:
		_next_sequence_low = 0
		_next_sequence_high += 1
		return
	_next_sequence_low += 1


func _sequence_room(count: int) -> bool:
	"""True when `count` more sequence numbers remain below the 2^64 ceiling, without wrapping."""
	if _next_sequence_high > U32_MAX:
		return false
	if _next_sequence_high < U32_MAX:
		return true
	return U32_MAX - _next_sequence_low + 1 >= count


func _accept(out: SubmitResult, accepted: int) -> bool:
	"""Record an accepted admission of `accepted` commands and return true."""
	_accepted_count += accepted
	_last_refusal = REFUSE_NONE
	out.fill(true, REFUSE_NONE, accepted, 0)
	return true


func _refuse(out: SubmitResult, code: StringName) -> bool:
	"""Record a refusal that wrote nothing and return false."""
	_refused_count += 1
	_last_refusal = code
	out.fill(false, code, 0, _refused_member)
	return false


# --- reading and draining -------------------------------------------------------------------------

func next_execute_tick() -> int:
	"""ARCH-CMD-001's `completed_tick+1`: the tick every edit submitted now is due at.

	While paused the completed tick does not move, so every paused edit shares this tick and is
	separated only by its increasing sequence.
	"""
	return _clock.completed_tick() + 1


func read_into(position: int, out: Command) -> bool:
	"""Read the command at queue position `position` (0 is next) into a caller-owned record."""
	if position < 0 or position >= _count:
		_last_refusal = REFUSE_POSITION
		return false
	_read_row(_row_at(position), out)
	return true


func peek_into(out: Command) -> bool:
	"""Read the command at the head of the queue without removing it."""
	return read_into(0, out)


func drain_due_into(executing_tick: int, out: Command) -> bool:
	"""Remove and return the next command due at or before `executing_tick`.

	This is the per-tick loop: call it until it answers false. False means nothing is due, which is
	the loop's normal terminator and sets no refusal. The drained command's payload bytes stay
	readable until the next accepted submission.
	"""
	if _count == 0:
		return false
	var row: int = _order[_head]
	if _execute_tick[row] > executing_tick:
		return false
	_read_row(row, out)
	_head = (_head + 1) % QUEUE_CAPACITY
	_count -= 1
	_drained_count += 1
	return true


func _read_row(row: int, out: Command) -> void:
	"""Copy storage row `row` into a caller-owned record, payload span included."""
	out.execute_tick = _execute_tick[row]
	out.player_id = _player_id[row]
	out.sequence_low = _sequence_low[row]
	out.sequence_high = _sequence_high[row]
	out.kind = _kind[row]
	out.target_slot = _target_slot[row]
	out.target_generation = _target_generation[row]
	out.goal_x = _goal_x[row]
	out.goal_z = _goal_z[row]
	out.arg0 = _arg0[row]
	out.arg1 = _arg1[row]
	out.payload_offset = _payload_offset[row]
	out.payload_length = _payload_length[row]
	out.flags = _flags[row]
	out.reserved_zero = _reserved_zero[row]


func read_payload_into(command: Command, out: PackedByteArray) -> bool:
	"""Copy a read or drained command's payload bytes into a caller-owned buffer.

	`out` must already be at least `payload_length` bytes: this never resizes the caller's buffer,
	so a tick's drain loop allocates nothing. Refuses an out-of-arena span rather than reading it.
	"""
	var refusal: StringName = payload_span_refusal(command.payload_offset, command.payload_length)
	if refusal != REFUSE_NONE:
		_last_refusal = refusal
		return false
	if out.size() < command.payload_length:
		_last_refusal = REFUSE_BUFFER_TOO_SMALL
		return false
	for index: int in command.payload_length:
		out[index] = _payload[command.payload_offset + index]
	return true


func payload_span_refusal(offset: int, length: int) -> StringName:
	"""Validate a `(payload_offset, payload_length)` pair against the arena, in checked integers."""
	if offset < 0 or length < 0:
		return REFUSE_PAYLOAD_SPAN
	if not IntMath.checked_add_into(offset, length, _math):
		return REFUSE_PAYLOAD_SPAN
	if _math.value > PAYLOAD_ARENA_BYTES:
		return REFUSE_PAYLOAD_SPAN
	return REFUSE_NONE


func due_count(executing_tick: int) -> int:
	"""How many queued commands are due at or before `executing_tick`."""
	var due: int = 0
	while due < _count and _execute_tick[_row_at(due)] <= executing_tick:
		due += 1
	return due


# --- §8.1 serialization (implemented, unwired: no save module exists) -----------------------------

static func encode_command_into(command: Command, out: PackedByteArray, byte_offset: int) -> bool:
	"""Write one record at §8.1's exact 64-byte layout into `out` at `byte_offset`.

	The only encoder in this module; `encode_record_into()` routes queued rows through it, so a
	moved offset moves in one place. Refuses a buffer that cannot hold the whole record.
	"""
	if byte_offset < 0 or out.size() < byte_offset + RECORD_BYTES:
		return false
	out.encode_s64(byte_offset + OFFSET_EXECUTE_TICK, command.execute_tick)
	out.encode_s32(byte_offset + OFFSET_PLAYER_ID, command.player_id)
	out.encode_u32(byte_offset + OFFSET_SEQUENCE_LOW, to_uint32(command.sequence_low))
	out.encode_u32(byte_offset + OFFSET_SEQUENCE_HIGH, to_uint32(command.sequence_high))
	out.encode_s32(byte_offset + OFFSET_KIND, command.kind)
	out.encode_s32(byte_offset + OFFSET_TARGET_SLOT, command.target_slot)
	out.encode_s32(byte_offset + OFFSET_TARGET_GENERATION, command.target_generation)
	out.encode_s32(byte_offset + OFFSET_GOAL_X, command.goal_x)
	out.encode_s32(byte_offset + OFFSET_GOAL_Z, command.goal_z)
	out.encode_s32(byte_offset + OFFSET_ARG0, command.arg0)
	out.encode_s32(byte_offset + OFFSET_ARG1, command.arg1)
	out.encode_s32(byte_offset + OFFSET_PAYLOAD_OFFSET, command.payload_offset)
	out.encode_s32(byte_offset + OFFSET_PAYLOAD_LENGTH, command.payload_length)
	out.encode_s32(byte_offset + OFFSET_FLAGS, command.flags)
	out.encode_s32(byte_offset + OFFSET_RESERVED_ZERO, command.reserved_zero)
	return true


static func decode_record_into(bytes: PackedByteArray, byte_offset: int, out: Command) -> bool:
	"""Read §8.1's 64 bytes at `byte_offset` back into a caller-owned record.

	Structural only: it bounds-checks the buffer and fills every field, including a nonzero
	`reserved_zero` so that `envelope_refusal()` can reject it. It never repairs a record.
	"""
	if byte_offset < 0 or bytes.size() < byte_offset + RECORD_BYTES:
		return false
	out.execute_tick = bytes.decode_s64(byte_offset + OFFSET_EXECUTE_TICK)
	out.player_id = bytes.decode_s32(byte_offset + OFFSET_PLAYER_ID)
	out.sequence_low = to_int32_bits(bytes.decode_u32(byte_offset + OFFSET_SEQUENCE_LOW))
	out.sequence_high = to_int32_bits(bytes.decode_u32(byte_offset + OFFSET_SEQUENCE_HIGH))
	out.kind = bytes.decode_s32(byte_offset + OFFSET_KIND)
	out.target_slot = bytes.decode_s32(byte_offset + OFFSET_TARGET_SLOT)
	out.target_generation = bytes.decode_s32(byte_offset + OFFSET_TARGET_GENERATION)
	out.goal_x = bytes.decode_s32(byte_offset + OFFSET_GOAL_X)
	out.goal_z = bytes.decode_s32(byte_offset + OFFSET_GOAL_Z)
	out.arg0 = bytes.decode_s32(byte_offset + OFFSET_ARG0)
	out.arg1 = bytes.decode_s32(byte_offset + OFFSET_ARG1)
	out.payload_offset = bytes.decode_s32(byte_offset + OFFSET_PAYLOAD_OFFSET)
	out.payload_length = bytes.decode_s32(byte_offset + OFFSET_PAYLOAD_LENGTH)
	out.flags = bytes.decode_s32(byte_offset + OFFSET_FLAGS)
	out.reserved_zero = bytes.decode_s32(byte_offset + OFFSET_RESERVED_ZERO)
	return true


func encode_record_into(position: int, out: PackedByteArray, byte_offset: int) -> bool:
	"""Encode the queued command at `position` into `out`, for a save or replay writer.

	Unwired: no save module exists in this repository, so nothing shipping calls this yet.
	"""
	if position < 0 or position >= _count:
		_last_refusal = REFUSE_POSITION
		return false
	_read_row(_row_at(position), _scratch)
	if not encode_command_into(_scratch, out, byte_offset):
		_last_refusal = REFUSE_BUFFER_TOO_SMALL
		return false
	return true


# --- session sequence, capacity and diagnostics ---------------------------------------------------

func restore_sequence(high: int, low: int) -> bool:
	"""Set the session sequence a loaded world resumes from. Only legal on an empty queue.

	§8.1's save header carries the "Replay command sequence at checkpoint" at offset 216; this is
	where it comes back. Restoring under a non-empty queue could mint a key already in it, so it
	refuses instead.
	"""
	if high < 0 or high > U32_MAX or low < 0 or low > U32_MAX:
		_last_refusal = REFUSE_SEQUENCE_RANGE
		return false
	if _count != 0:
		_last_refusal = REFUSE_QUEUE_NOT_EMPTY
		return false
	_next_sequence_high = high
	_next_sequence_low = low
	_last_refusal = REFUSE_NONE
	return true


func rebind_clock(p_clock: SimClock) -> bool:
	"""Point this queue at another clock. Only legal on an EMPTY queue, and never at null.

	`GameManager.start_game()` replaces its `SimClock` instance, so ARCH-SYS-002's composition has
	to be able to follow it or it would go on stamping `completed_tick+1` from a clock that stopped
	moving. Rebinding under a non-empty queue is refused rather than performed: the pending records
	were stamped against the OLD clock's tick numbering, and re-basing them would silently move
	when a player's edits execute.
	"""
	if p_clock == null:
		_last_refusal = REFUSE_NO_CLOCK
		return false
	if _count != 0:
		_last_refusal = REFUSE_QUEUE_NOT_EMPTY
		return false
	_clock = p_clock
	_last_refusal = REFUSE_NONE
	return true


func is_valid_kind(kind: int) -> bool:
	"""True for one of ARCH-CMD-003's compiled kind ids. The domain is contiguous from 0."""
	return kind >= 0 and kind < _kind_count


func kind_count() -> int:
	"""How many command kinds the compiled ARCH-CMD-003 domain carries."""
	return _kind_count


func capacity() -> int:
	"""§8.1's in-memory queue length."""
	return QUEUE_CAPACITY


func pending_count() -> int:
	"""How many accepted commands are queued and unconsumed."""
	return _count


func free_count() -> int:
	"""How many more commands the queue can accept before it refuses."""
	return QUEUE_CAPACITY - _count


func payload_used() -> int:
	"""Arena bytes currently reserved by queued commands."""
	return 0 if _count == 0 else _payload_used


func payload_available() -> int:
	"""Arena bytes still allocatable, counting the reclaim an empty queue has already earned."""
	return PAYLOAD_ARENA_BYTES - payload_used()


func next_sequence_high() -> int:
	"""The unsigned high word the next stamped command will carry."""
	return _next_sequence_high


func next_sequence_low() -> int:
	"""The unsigned low word the next stamped command will carry."""
	return _next_sequence_low


func accepted_count() -> int:
	"""How many commands this queue has accepted since `clear()`."""
	return _accepted_count


func refused_count() -> int:
	"""How many admission attempts this queue has refused since `clear()`."""
	return _refused_count


func drained_count() -> int:
	"""How many commands this queue has handed to a tick since `clear()`."""
	return _drained_count


func last_refusal() -> StringName:
	"""The most recent refusal code, or REFUSE_NONE after a successful admission."""
	return _last_refusal


func clock() -> SimClock:
	"""The clock supplying `completed_tick`, so a caller can share exactly this one."""
	return _clock


func directory() -> EntityDirectory:
	"""The directory every target EntityRef is validated against."""
	return _directory
