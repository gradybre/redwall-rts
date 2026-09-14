extends RefCounted
## ARCH-SAVE-002 section 12 PENDING_COMMANDS: the two command queues a paused world must carry
## across a process restart -- `commands.gd`'s economic edits and `scheduler_events.gd`'s
## speed/pause events.
##
## ## WHICH §12 FRAMING THIS IMPLEMENTS, AND THE CONTRADICTION IT RESOLVES
##
## Two adopted documents describe section 12 differently and this module follows the RULING,
## because AGENTS.md's authority order puts `docs/rulings/` above a working instruction:
##
##   * SAVE-LAYOUT-R01 (2026-09-12), "RNG and fixed-format exceptions": "Retain the existing
##     explicit formats: ... section12's schema2 prefix, 64-byte economic records, payload and
##     record-major SCHQ0001 extension ... Their record layouts override the packed-store
##     default." REG-R01 repeats it: "Preserve the distinct existing forms of §10, §11, §12, §13
##     and §15 in SAVE-R09 / SAVE-LAYOUT-R01."
##   * The generic `store_count:u32` + per-owner wrapper + COLUMN-MAJOR framing that
##     SAVE-LAYOUT-R01 adopts for §§3/4/5 is, in that same ruling's words, what §12's record
##     layout OVERRIDES. Section 12 is named in the exception list beside §10, which likewise has
##     "no generic store wrapper for this compact schema".
##
## So there is no `store_count`, no `owner_key:utf8-u32` wrapper and no column-major payload here.
## The owner keys `commands` and `scheduler_events` still exist and still order ASCII-first:
## `commands` supplies the prefix and the economic records, `scheduler_events` the trailing
## `SCHQ0001` extension, exactly that way round. See BLOCKER P1 below; this is a reported
## divergence from the lane brief, not an unnoticed one.
##
## §12 IS ALREADY AT SCHEMA 2 AND IS NOT BUMPED. REG-R01's baseline vector is
## `[2,2,1,2,1,1,2,1,2,1,1,2,1,2,1]` with the note "§12 was already 2". The 2 is physically
## present as the prefix's first u32 (`SECTION_SCHEMA_VERSION_TWO` in `scheduler_events.gd`), and
## the nested `SCHQ0001` stays at schema 1.
##
## ## THE BYTES
##
## `docs/planning/ready07_scheduler_contract.md` fixes every number below; none is invented here.
## E = pending economic commands, P = economic payload used bytes, S = pending scheduler events.
##
##   | Offset          | Type       | Field                                     | Bytes |
##   |----------------:|------------|-------------------------------------------|------:|
##   | 0               | u32        | section_schema = 2                        |     4 |
##   | 4               | u32        | economic_count E (<= 4096)                |     4 |
##   | 8               | u32        | economic_payload_used P (<= 1048576)      |     4 |
##   | 12              | u32        | scheduler_extension_bytes X = 48 + 32*S   |     4 |
##   | 16              | u32        | economic_next_sequence_low                |     4 |
##   | 20              | u32        | economic_next_sequence_high               |     4 |
##   | 24              | 64 x E     | economic records, canonical command order | 64*E  |
##   | 24+64E          | u8 x P     | economic payload arena used prefix        |     P |
##   | 24+64E+P        | ascii      | `SCHQ0001`                                |     8 |
##   | 32+64E+P        | u32        | extension schema_version = 1              |     4 |
##   | 36+64E+P        | u32        | extension payload length = 32 + 32*S      |     4 |
##   | 40+64E+P        | -          | (control block begins at +48 from tag)    |       |
##   | 40+64E+P        | 32 bytes   | queue control, canonical head = 0         |    32 |
##   | 72+64E+P        | 32 x S     | scheduler records, queue order            | 32*S  |
##
## Section length = `72 + 64*E + P + 32*S`, which is `scheduler_events.gd::section_twelve_length()`
## and is called rather than restated. An empty §12 is 72 bytes, never zero.
##
## ## RING BUFFERS: THE LIVE WINDOW IS PERSISTED, THE TAIL IS REBUILT
##
## Both owners are rings. `commands.gd` holds 4096 rows plus an `_order` permutation and a ring
## `_head`; `scheduler_events.gd` holds 256 rows and a ring `_head`. In BOTH, only the `_count`
## positions from `_head` mean anything and the rest hold whatever a drained record left behind.
## `save_section_directory.gd` already ruled the general case for the free heaps: "Two worlds that
## are identical in every observable way can hold different garbage there, so a section 3 that
## wrote the heaps would make those two worlds produce different bytes and different CRCs."
##
## So this module reads rows ONLY through `read_into(position, ...)`, which resolves `_head` and
## `_order` for it, writes exactly E and S records in queue order, and serializes NO unused row.
## `_head` itself is category 2 in `docs/persistence_state_registry.md` ("Records are written in
## canonical order and restored from row 0, so its canonical restored value is 0") and the
## contract requires the stored control head to BE 0; `_order` is category 2 for the same reason.
## `Record`'s own columns carry the declared canonical unused values past the live window and
## `_ring_tail_refusal()` refuses a Record that smuggled garbage into them, so a capture that
## copied raw rows instead of queue positions cannot round-trip.
##
## THE PAYLOAD ARENA IS A COUNT-THEN-PREFIX LAYOUT AND GETS THE SAME DISCIPLINE. P is the arena's
## used prefix, which ready07 requires preserved because consumed space "still affects admission".
## Bytes INSIDE that prefix that no pending command's span covers are dead: a drained command's
## bytes stay readable until the next submission, and two observationally identical worlds hold
## different dead bytes there. ARCH-SAVE-002's rule quoted on the registry's own arena row --
## "encode zero for unused payload" -- settles it: the live spans are verbatim, every other byte
## of the arena is zero, and `_payload_refusal()` refuses a Record that is not in that form.
##
## ## THE int32/int64 SIGN TRAP IS THIS SECTION'S CENTRAL HAZARD
##
## GDScript ints are 64-bit, so `0x80000000` is a POSITIVE 2147483648 while `-2147483648` is the
## same four bytes read as int32. BOTH queues keep u32 sequence BITS in `PackedInt32Array`
## columns, so a session counter past 2147483648 stores a NEGATIVE i32 -- and a signed comparison
## puts 0x80000000 before 0x7fffffff, silently reordering two commands the player issued in the
## opposite order, with no error anywhere. Every ordering test here goes through
## `commands.gd::compare_key_parts()` or `scheduler_events.gd::compare_sequence()`, which mask
## first. Record columns hold the i32 SPELLING (what the store's column holds); the wire holds the
## u32 BITS, and `encode_command_into()`/`decode_record_into()` are the only conversion.
## The four `next_sequence` scalars are UNSIGNED 0..4294967295, because that is what
## `restore_sequence()` accepts and what the prefix's u32 fields carry.
##
## ## ALLOCATE BEFORE CONSUME (decision 0059)
##
## `decode_into()` proves the whole extent, parses into a LOCAL Record, validates every framing
## field, every column domain and every cross-column invariant, and only then copies into the
## caller's Record -- so a FULL-LENGTH but invalid section leaves `out` byte-identical.
## `apply()` validates the Record, proves the arena is rebuildable, proves BOTH stores are empty,
## and runs `scheduler_events.gd::extension_refusal()` and `commands.gd::envelope_refusal()` over
## every incoming record BEFORE the first store mutation. A refusal leaves both collaborating
## stores byte-identical, and `test_save_section_pending_commands.gd` asserts that by re-encoding
## them and comparing bytes, not by inspecting a flag.
##
## ## RESTORE GOES THROUGH THE OWNERS' PUBLISHED APIS, NEVER THEIR COLUMNS
##
## `save_section_world_runtime.gd` installs through `sim_clock.gd::restore_runtime()`; this module
## does the same thing twice. `scheduler_events.gd::restore_extension()` takes the `SCHQ0001`
## bytes, so `apply()` rebuilds that subsection from the Record with the SAME private writer
## `encode_record()` uses and hands it over -- the owner then revalidates tag, lengths, count,
## reason ownership, zero padding, sequence order and `pending boundary == saved completed tick`
## before it writes a column. `commands.gd` gets `restore_sequence()` then one
## `admit_stamped_into()` per record in canonical order. Both restore paths deliberately pass
## THROUGH the load barrier: restore is not a command (RESTORE-R01).
##
## ORDERING OBLIGATION ON THE LOAD ORCHESTRATOR. §1 WORLD's clock and §3 ENTITY_DIRECTORY must be
## restored BEFORE §12. `admit_stamped_into()` refuses a tick at or before `completed_tick()` and
## validates every target `EntityRef` against the live directory, and `restore_extension()`
## compares every pending boundary against the saved completed tick. Restoring §12 first would
## refuse a perfectly good save.
##
## ## BLOCKER P1 -- THE LANE BRIEF ASKS FOR A FRAMING SAVE-LAYOUT-R01 EXEMPTS
##
## The instruction that opened this work specified `store_count:u32` then one standard owner
## wrapper per owner in ASCII key order, column-major. SAVE-LAYOUT-R01 names section 12 in its
## fixed-format exception list in the same breath as section 10, whose compact schema it says has
## "no generic store wrapper", and REG-R01 repeats "preserve the distinct existing forms of ...
## §12". Three further facts point the same way: the "already 2" schema version physically IS the
## prefix's first u32 and has nowhere to live in the wrapper form; `scheduler_events.gd` already
## ships `section_twelve_length()`, `section_twelve_refusal()` and `encode_section_prefix_into()`
## labelled "container version 2's section 12 arithmetic"; and REG-R01's own §12 field ordinals
## reproduce the 64-byte and 32-byte RECORD field orders exactly (ordinals 4..18 for `commands`
## are §8.1's record fields in §8.1's order; ordinals 7..13 for `scheduler_events` are the 32-byte
## record's). Those ordinals are honoured here as the CANONICAL FIELD-RECORD STREAM order for
## §15's walker, which REG-R01 distinguishes from the wire: "The artifact defines the logical
## field-record stream." REPORTED, not silently chosen. If a later ruling does move §12 onto the
## generic wrapper, `SECTION_SCHEMA_VERSION` and the whole prefix change together.
##
## ## BLOCKER P2 -- `commands.gd` HAS NO ARENA-BASE RESTORE, SO A SPLIT DRAIN REFUSES
##
## `_allocate_payload()` is a bump cursor that resets only when the queue is empty, so restoring
## through `admit_stamped_into()` always lays the pending payloads out contiguously from offset 0.
## A world saved with a NON-ZERO first pending offset -- reachable only when a partial drain left
## the queue non-empty, which `submit_into()`'s uniform `completed_tick+1` stamping cannot produce
## and only a replay stream with mixed future ticks can -- cannot be reproduced through any public
## `commands.gd` API. `arena_rebuild_refusal()` therefore refuses at CAPTURE as well as at apply,
## because writing a save that cannot be loaded is worse than refusing to write one. Closing this
## needs `commands.gd` to publish an arena-base restore; that file is not this lane's to change.
##
## ## COLD PATH, NO FLOAT
##
## ARCH-SAVE-003 saves at a completed boundary and loads at a load boundary, so `Record`,
## `EncodeResult` and the codec buffers are bounded cold-path scratch, not per-tick allocation;
## ARCH-MEM-001's ban applies to the owners' columns, which this module only mirrors. There is no
## float in this file and `test_save_section_pending_commands.gd` greps this source to keep it so.

const SaveCodec := preload("res://scripts/core/save_codec.gd")
const SaveHeader := preload("res://scripts/core/save_header.gd")
const CommandsScript := preload("res://scripts/core/commands.gd")
const SchedulerEventsScript := preload("res://scripts/core/scheduler_events.gd")
const CatalogScript := preload("res://scripts/core/catalog.gd")
const EntityDirectoryScript := preload("res://scripts/core/entity_directory.gd")

# --- ARCH-SAVE-002 identity -----------------------------------------------------------------------

## ARCH-SAVE-002's section order: "... 11 EVENT_SCHEDULE, 12 PENDING_COMMANDS, ...".
const SECTION_ID: int = 12

## REG-R01: "§12 was already 2". Read off `scheduler_events.gd` so the two cannot drift.
const SECTION_SCHEMA_VERSION: int = SchedulerEventsScript.SECTION_SCHEMA_VERSION_TWO

## The two registered owners, in the ASCII order REG-R01 orders blocks by. `commands` owns the
## prefix and the economic records; `scheduler_events` owns the trailing `SCHQ0001` extension.
const OWNER_KEY_COMMANDS: String = "commands"
const OWNER_KEY_SCHEDULER: String = "scheduler_events"
const OWNER_SCHEMA_VERSION_COMMANDS: int = 1
const OWNER_SCHEMA_VERSION_SCHEDULER: int = 1

# --- layout, every number read off its owner --------------------------------------------------------

const PREFIX_BYTES: int = SchedulerEventsScript.SECTION_PREFIX_BYTES
const OFFSET_PREFIX_SECTION_SCHEMA: int = SchedulerEventsScript.OFFSET_PREFIX_SECTION_SCHEMA
const OFFSET_PREFIX_ECONOMIC_COUNT: int = SchedulerEventsScript.OFFSET_PREFIX_ECONOMIC_COUNT
const OFFSET_PREFIX_PAYLOAD_USED: int = SchedulerEventsScript.OFFSET_PREFIX_ECONOMIC_PAYLOAD_USED
const OFFSET_PREFIX_EXTENSION_BYTES: int = \
	SchedulerEventsScript.OFFSET_PREFIX_SCHEDULER_EXTENSION_BYTES
const OFFSET_PREFIX_NEXT_SEQUENCE_LOW: int = \
	SchedulerEventsScript.OFFSET_PREFIX_ECONOMIC_NEXT_SEQUENCE_LOW
const OFFSET_PREFIX_NEXT_SEQUENCE_HIGH: int = \
	SchedulerEventsScript.OFFSET_PREFIX_ECONOMIC_NEXT_SEQUENCE_HIGH

const ECONOMIC_CAPACITY: int = CommandsScript.QUEUE_CAPACITY
const ECONOMIC_RECORD_BYTES: int = CommandsScript.RECORD_BYTES
const PAYLOAD_ARENA_BYTES: int = CommandsScript.PAYLOAD_ARENA_BYTES

const SCHEDULER_CAPACITY: int = SchedulerEventsScript.QUEUE_CAPACITY
const SCHEDULER_RECORD_BYTES: int = SchedulerEventsScript.RECORD_BYTES
const CONTROL_BYTES: int = SchedulerEventsScript.CONTROL_BYTES
const EXTENSION_HEADER_BYTES: int = SchedulerEventsScript.EXTENSION_HEADER_BYTES
const EXTENSION_FIXED_BYTES: int = SchedulerEventsScript.EXTENSION_FIXED_BYTES
const SECTION_TAG: String = SchedulerEventsScript.SECTION_TAG
const SECTION_TAG_BYTES: int = SchedulerEventsScript.SECTION_TAG_BYTES
const EXTENSION_SCHEMA_VERSION: int = SchedulerEventsScript.SECTION_SCHEMA_VERSION

## `72 + 64*0 + 0 + 32*0`, and `72 + 64*4096 + 1048576 + 32*256`. Both stated so a reader can see
## the bound without running the arithmetic; `section_byte_length()` recomputes them.
const EMPTY_SECTION_BYTES: int = 72
const MAX_SECTION_BYTES: int = 1318984

const U32_MAX: int = CommandsScript.U32_MAX
const NULL_SLOT: int = EntityDirectoryScript.NULL_SLOT
const NULL_GENERATION: int = EntityDirectoryScript.NULL_GENERATION
const RELEASE_ONE_PLAYER_ID: int = CommandsScript.RELEASE_ONE_PLAYER_ID
const SCHEDULER_KIND_COUNT: int = SchedulerEventsScript.KIND_COUNT
const NO_PRIOR_DRAIN: int = SchedulerEventsScript.NO_PRIOR_DRAIN

# --- REG-R01's declared field ordinals ---------------------------------------------------------------
#
# BINDING, and NOT GDScript declaration order. These are the canonical field-record ordinals from
# `docs/planning/canonical_state_registry.json`; §15's walker emits records in this order, and the
# suite asserts that the record columns this module encodes follow ordinals 4..18 and 7..13.

const FIELD_COMMANDS_COUNT: int = 0
const FIELD_COMMANDS_PAYLOAD_USED: int = 1
const FIELD_COMMANDS_NEXT_SEQUENCE_HIGH: int = 2
const FIELD_COMMANDS_NEXT_SEQUENCE_LOW: int = 3
const FIELD_COMMANDS_FIRST_RECORD: int = 4
const FIELD_COMMANDS_PAYLOAD: int = 19
const FIELD_COMMANDS_COUNT_TOTAL: int = 20

const FIELD_SCHEDULER_HEAD: int = 0
const FIELD_SCHEDULER_COUNT: int = 1
const FIELD_SCHEDULER_NEXT_SEQUENCE_LOW: int = 2
const FIELD_SCHEDULER_NEXT_SEQUENCE_HIGH: int = 3
const FIELD_SCHEDULER_LAST_APPLIED_LOW: int = 4
const FIELD_SCHEDULER_LAST_APPLIED_HIGH: int = 5
const FIELD_SCHEDULER_LAST_DRAINED_BOUNDARY: int = 6
const FIELD_SCHEDULER_FIRST_RECORD: int = 7
const FIELD_SCHEDULER_COUNT_TOTAL: int = 14

## Registry field keys in declared ordinal order. Underscores are kept, as REG-R01 requires.
const FIELD_KEYS_COMMANDS: Array[StringName] = [
	&"_count", &"_payload_used", &"_next_sequence_high", &"_next_sequence_low",
	&"_execute_tick", &"_player_id", &"_sequence_low", &"_sequence_high", &"_kind",
	&"_target_slot", &"_target_generation", &"_goal_x", &"_goal_z", &"_arg0", &"_arg1",
	&"_payload_offset", &"_payload_length", &"_flags", &"_reserved_zero", &"_payload",
]

const FIELD_KEYS_SCHEDULER: Array[StringName] = [
	&"_head", &"_count", &"_next_sequence_low", &"_next_sequence_high",
	&"_last_applied_sequence_low", &"_last_applied_sequence_high", &"_last_drained_boundary",
	&"_boundary_tick", &"_sequence_low", &"_sequence_high", &"_kind", &"_reason", &"_value",
	&"_reserved",
]

# --- refusal codes (this module never returns a sentinel to signal failure) -----------------------

const REFUSE_NONE: StringName = SaveHeader.REFUSE_NONE
const REFUSE_NEGATIVE_OFFSET: StringName = &"SAVE_PC_NEGATIVE_OFFSET"
const REFUSE_TRUNCATED: StringName = &"SAVE_PC_TRUNCATED"
const REFUSE_SECTION_SCHEMA: StringName = &"SAVE_PC_SECTION_SCHEMA"
const REFUSE_LENGTH: StringName = &"SAVE_PC_LENGTH"
const REFUSE_ECONOMIC_COUNT: StringName = &"SAVE_PC_ECONOMIC_COUNT"
const REFUSE_PAYLOAD_USED: StringName = &"SAVE_PC_PAYLOAD_USED"
const REFUSE_SCHEDULER_COUNT: StringName = &"SAVE_PC_SCHEDULER_COUNT"
const REFUSE_EXTENSION_LENGTH: StringName = &"SAVE_PC_EXTENSION_LENGTH"
const REFUSE_EXTENSION_TAG: StringName = &"SAVE_PC_EXTENSION_TAG"
const REFUSE_EXTENSION_VERSION: StringName = &"SAVE_PC_EXTENSION_VERSION"
const REFUSE_RECORD_SHAPE: StringName = &"SAVE_PC_RECORD_SHAPE"
const REFUSE_SEQUENCE_RANGE: StringName = &"SAVE_PC_SEQUENCE_RANGE"
const REFUSE_SEQUENCE_ORDER: StringName = &"SAVE_PC_SEQUENCE_ORDER"
const REFUSE_KEY_ORDER: StringName = &"SAVE_PC_KEY_ORDER"
const REFUSE_PLAYER_ID: StringName = &"SAVE_PC_PLAYER_ID"
const REFUSE_UNKNOWN_KIND: StringName = &"SAVE_PC_UNKNOWN_KIND"
const REFUSE_FLAGS_UNDEFINED: StringName = &"SAVE_PC_FLAGS_UNDEFINED"
const REFUSE_RESERVED_NONZERO: StringName = &"SAVE_PC_RESERVED_NONZERO"
const REFUSE_TARGET_MALFORMED: StringName = &"SAVE_PC_TARGET_MALFORMED"
const REFUSE_FIELD_RANGE: StringName = &"SAVE_PC_FIELD_RANGE"
const REFUSE_PAYLOAD_SPAN: StringName = &"SAVE_PC_PAYLOAD_SPAN"
const REFUSE_PAYLOAD_OVERLAP: StringName = &"SAVE_PC_PAYLOAD_OVERLAP"
const REFUSE_PAYLOAD_GARBAGE: StringName = &"SAVE_PC_PAYLOAD_GARBAGE"
const REFUSE_RING_TAIL_GARBAGE: StringName = &"SAVE_PC_RING_TAIL_GARBAGE"
const REFUSE_HEAD_NOT_CANONICAL: StringName = &"SAVE_PC_HEAD_NOT_CANONICAL"
const REFUSE_BOUNDARY_MISMATCH: StringName = &"SAVE_PC_BOUNDARY_MISMATCH"
const REFUSE_CONTROL: StringName = &"SAVE_PC_CONTROL"
const REFUSE_ARENA_NOT_REBUILDABLE: StringName = &"SAVE_PC_ARENA_NOT_REBUILDABLE"
const REFUSE_STORE_NOT_EMPTY: StringName = &"SAVE_PC_STORE_NOT_EMPTY"
const REFUSE_STORE_REFUSED: StringName = &"SAVE_PC_STORE_REFUSED"
const REFUSE_ENCODE_FAILED: StringName = &"SAVE_PC_ENCODE_FAILED"


class Record:
	"""One decoded section 12: both owners' live windows, in structure-of-arrays columns.

	Every column is allocated once in `_init` at its owner's full ring capacity and never resized
	again. Only `[0, economic_count)` and `[0, scheduler_count)` are meaningful; the tail carries
	the DECLARED canonical unused values (`_target_slot` -1, everything else 0) so that two worlds
	holding different ring garbage still produce identical bytes. `_order`, both `_head` values and
	every diagnostic counter are deliberately absent -- see the module header.
	"""
	var economic_count: int = 0
	var payload_used: int = 0
	var economic_next_sequence_high: int = 0
	var economic_next_sequence_low: int = 0

	var execute_tick: PackedInt64Array = PackedInt64Array()
	var player_id: PackedInt32Array = PackedInt32Array()
	var sequence_low: PackedInt32Array = PackedInt32Array()
	var sequence_high: PackedInt32Array = PackedInt32Array()
	var kind: PackedInt32Array = PackedInt32Array()
	var target_slot: PackedInt32Array = PackedInt32Array()
	var target_generation: PackedInt32Array = PackedInt32Array()
	var goal_x: PackedInt32Array = PackedInt32Array()
	var goal_z: PackedInt32Array = PackedInt32Array()
	var arg0: PackedInt32Array = PackedInt32Array()
	var arg1: PackedInt32Array = PackedInt32Array()
	var payload_offset: PackedInt32Array = PackedInt32Array()
	var payload_length: PackedInt32Array = PackedInt32Array()
	var flags: PackedInt32Array = PackedInt32Array()
	var reserved_zero: PackedInt32Array = PackedInt32Array()
	var payload: PackedByteArray = PackedByteArray()

	var scheduler_head: int = 0
	var scheduler_count: int = 0
	var scheduler_next_sequence_low: int = 0
	var scheduler_next_sequence_high: int = 0
	var scheduler_last_applied_low: int = 0
	var scheduler_last_applied_high: int = 0
	var scheduler_last_drained_boundary: int = NO_PRIOR_DRAIN

	var boundary_tick: PackedInt64Array = PackedInt64Array()
	var event_sequence_low: PackedInt32Array = PackedInt32Array()
	var event_sequence_high: PackedInt32Array = PackedInt32Array()
	var event_kind: PackedInt32Array = PackedInt32Array()
	var event_reason: PackedInt32Array = PackedInt32Array()
	var event_value: PackedInt32Array = PackedInt32Array()
	var event_reserved: PackedInt32Array = PackedInt32Array()

	func _init() -> void:
		"""Allocate every column at its owner's ring capacity. The only place this class resizes."""
		execute_tick.resize(ECONOMIC_CAPACITY)
		for column: PackedInt32Array in economic_columns():
			column.resize(ECONOMIC_CAPACITY)
		payload.resize(PAYLOAD_ARENA_BYTES)
		boundary_tick.resize(SCHEDULER_CAPACITY)
		for column: PackedInt32Array in scheduler_columns():
			column.resize(SCHEDULER_CAPACITY)
		clear()

	func economic_columns() -> Array[PackedInt32Array]:
		"""The fourteen i32 economic columns, in declared ordinal order 5..18."""
		return [player_id, sequence_low, sequence_high, kind, target_slot, target_generation,
			goal_x, goal_z, arg0, arg1, payload_offset, payload_length, flags, reserved_zero]

	func scheduler_columns() -> Array[PackedInt32Array]:
		"""The six i32 scheduler columns, in declared ordinal order 8..13."""
		return [event_sequence_low, event_sequence_high, event_kind, event_reason, event_value,
			event_reserved]

	func clear() -> void:
		"""Reset to the empty §12: both windows closed, every column at its canonical unused value.

		SAVE-LAYOUT-R01: "Use zero only where the owner declares zero." `commands.gd::clear()`
		declares -1 for `_target_slot` and 0 for `_target_generation`, so this does the same.
		"""
		_clear_economic()
		_clear_scheduler()

	func _clear_economic() -> void:
		"""Close the economic window and refill its columns and arena with the unused values."""
		economic_count = 0
		payload_used = 0
		economic_next_sequence_high = 0
		economic_next_sequence_low = 0
		execute_tick.fill(0)
		player_id.fill(0)
		sequence_low.fill(0)
		sequence_high.fill(0)
		kind.fill(0)
		target_slot.fill(NULL_SLOT)
		target_generation.fill(NULL_GENERATION)
		goal_x.fill(0)
		goal_z.fill(0)
		arg0.fill(0)
		arg1.fill(0)
		payload_offset.fill(0)
		payload_length.fill(0)
		flags.fill(0)
		reserved_zero.fill(0)
		payload.fill(0)

	func _clear_scheduler() -> void:
		"""Close the scheduler window and refill its columns with the contract's initial state."""
		scheduler_head = 0
		scheduler_count = 0
		scheduler_next_sequence_low = 0
		scheduler_next_sequence_high = 0
		scheduler_last_applied_low = 0
		scheduler_last_applied_high = 0
		scheduler_last_drained_boundary = NO_PRIOR_DRAIN
		boundary_tick.fill(0)
		event_sequence_low.fill(0)
		event_sequence_high.fill(0)
		event_kind.fill(0)
		event_reason.fill(0)
		event_value.fill(0)
		event_reserved.fill(0)

	func copy_from(other: Record) -> void:
		"""Overwrite this Record from `other`. Packed copies are C++ calls, so there is no loop."""
		_copy_economic_from(other)
		_copy_scheduler_from(other)

	func _copy_economic_from(other: Record) -> void:
		"""Copy the economic scalars, the fifteen record columns and the whole arena."""
		economic_count = other.economic_count
		payload_used = other.payload_used
		economic_next_sequence_high = other.economic_next_sequence_high
		economic_next_sequence_low = other.economic_next_sequence_low
		execute_tick = other.execute_tick.duplicate()
		player_id = other.player_id.duplicate()
		sequence_low = other.sequence_low.duplicate()
		sequence_high = other.sequence_high.duplicate()
		kind = other.kind.duplicate()
		target_slot = other.target_slot.duplicate()
		target_generation = other.target_generation.duplicate()
		goal_x = other.goal_x.duplicate()
		goal_z = other.goal_z.duplicate()
		arg0 = other.arg0.duplicate()
		arg1 = other.arg1.duplicate()
		payload_offset = other.payload_offset.duplicate()
		payload_length = other.payload_length.duplicate()
		flags = other.flags.duplicate()
		reserved_zero = other.reserved_zero.duplicate()
		payload = other.payload.duplicate()

	func _copy_scheduler_from(other: Record) -> void:
		"""Copy the seven scheduler control scalars and the seven record columns."""
		scheduler_head = other.scheduler_head
		scheduler_count = other.scheduler_count
		scheduler_next_sequence_low = other.scheduler_next_sequence_low
		scheduler_next_sequence_high = other.scheduler_next_sequence_high
		scheduler_last_applied_low = other.scheduler_last_applied_low
		scheduler_last_applied_high = other.scheduler_last_applied_high
		scheduler_last_drained_boundary = other.scheduler_last_drained_boundary
		boundary_tick = other.boundary_tick.duplicate()
		event_sequence_low = other.event_sequence_low.duplicate()
		event_sequence_high = other.event_sequence_high.duplicate()
		event_kind = other.event_kind.duplicate()
		event_reason = other.event_reason.duplicate()
		event_value = other.event_value.duplicate()
		event_reserved = other.event_reserved.duplicate()

	func equals(other: Record) -> bool:
		"""True when every scalar and every column is identical. Proves a refusal changed nothing."""
		return _economic_equals(other) and _scheduler_equals(other)

	func _economic_equals(other: Record) -> bool:
		"""True when the economic scalars, all fifteen columns and the whole arena agree."""
		if economic_count != other.economic_count or payload_used != other.payload_used:
			return false
		if economic_next_sequence_high != other.economic_next_sequence_high:
			return false
		if economic_next_sequence_low != other.economic_next_sequence_low:
			return false
		if execute_tick != other.execute_tick or payload != other.payload:
			return false
		var mine: Array[PackedInt32Array] = economic_columns()
		var theirs: Array[PackedInt32Array] = other.economic_columns()
		for index: int in mine.size():
			if mine[index] != theirs[index]:
				return false
		return true

	func _scheduler_equals(other: Record) -> bool:
		"""True when the seven scheduler scalars and all seven record columns agree."""
		if scheduler_head != other.scheduler_head or scheduler_count != other.scheduler_count:
			return false
		if scheduler_next_sequence_low != other.scheduler_next_sequence_low:
			return false
		if scheduler_next_sequence_high != other.scheduler_next_sequence_high:
			return false
		if scheduler_last_applied_low != other.scheduler_last_applied_low:
			return false
		if scheduler_last_applied_high != other.scheduler_last_applied_high:
			return false
		if scheduler_last_drained_boundary != other.scheduler_last_drained_boundary:
			return false
		if boundary_tick != other.boundary_tick:
			return false
		var mine: Array[PackedInt32Array] = scheduler_columns()
		var theirs: Array[PackedInt32Array] = other.scheduler_columns()
		for index: int in mine.size():
			if mine[index] != theirs[index]:
				return false
		return true


class EncodeResult:
	"""Outcome of materialising a whole section 12: the payload bytes, or a refusal and no bytes."""
	var ok: bool = false
	var bytes: PackedByteArray = PackedByteArray()
	var refusal: StringName = REFUSE_NONE
	var detail: String = ""

	func succeed(p_bytes: PackedByteArray) -> bool:
		"""Record the encoded section; always returns true."""
		ok = true
		bytes = p_bytes
		refusal = REFUSE_NONE
		detail = ""
		return true

	func refuse(p_refusal: StringName, p_detail: String) -> bool:
		"""Record a refusal with an empty payload; always returns false."""
		ok = false
		bytes = PackedByteArray()
		refusal = p_refusal
		detail = p_detail
		return false


# --- layout arithmetic ------------------------------------------------------------------------------

static func section_byte_length(record: Record) -> int:
	"""`72 + 64*E + P + 32*S` for this Record, through `scheduler_events.gd`'s own formula.

	Arithmetic, not a gate: `record_refusal()` has to have bounded E, P and S first. Delegating
	means the section directory's length and the prefix's `scheduler_extension_bytes` can never be
	derived from two different formulas.
	"""
	return SchedulerEventsScript.section_twelve_length(record.economic_count, record.payload_used,
		record.scheduler_count)


static func extension_byte_length(scheduler_count: int) -> int:
	"""The contract's `X = 48 + 32*S`, the trailing `SCHQ0001` subsection's size."""
	return EXTENSION_FIXED_BYTES + SCHEDULER_RECORD_BYTES * scheduler_count


static func scheduler_count_of_extension_bytes(extension_bytes: int) -> int:
	"""S recovered from X, or -1 when X is not `48 + 32*S`. Callers gate on the -1 explicitly.

	This is a SHAPE PREDICATE inverse, not a failure sentinel dressed as a count: `extent_refusal()`
	tests it and refuses SAVE_PC_EXTENSION_LENGTH before the value is used for anything.
	"""
	if extension_bytes < EXTENSION_FIXED_BYTES:
		return -1
	var records: int = extension_bytes - EXTENSION_FIXED_BYTES
	if records % SCHEDULER_RECORD_BYTES != 0:
		return -1
	return records / SCHEDULER_RECORD_BYTES


static func economic_record_offset(index: int) -> int:
	"""Byte offset, from the start of the section, of economic record `index`."""
	return PREFIX_BYTES + ECONOMIC_RECORD_BYTES * index


static func payload_offset_of(economic_count: int) -> int:
	"""Byte offset, from the start of the section, of the economic payload used prefix."""
	return economic_record_offset(economic_count)


static func extension_offset_of(economic_count: int, payload_used: int) -> int:
	"""Byte offset, from the start of the section, of the `SCHQ0001` tag."""
	return payload_offset_of(economic_count) + payload_used


static func descriptor_row_count(record: Record) -> int:
	"""The §12 descriptor's row_count: the two live windows, never either ring's capacity.

	Section 12 serializes no unused row, so unlike §3 the descriptor cannot be a capacity.
	"""
	return record.economic_count + record.scheduler_count


# --- capture ------------------------------------------------------------------------------------------

static func capture_into(commands_store: CommandsScript,
		scheduler_store: SchedulerEventsScript, out: Record) -> SaveHeader.Refusal:
	"""Capture both live queues' pending windows into `out`, validating before anything lands.

	Rows are read through `read_into(position, ...)`, which resolves each ring's `_head` and, for
	`commands.gd`, its `_order` permutation -- so a wrapped head is read in queue order and the
	stale tail is never touched. `out` is untouched unless every rule passes (decision 0059).
	"""
	var staged: Record = Record.new()
	var economic: SaveHeader.Refusal = _capture_economic(commands_store, staged)
	if not economic.is_ok():
		return economic
	var scheduler: SaveHeader.Refusal = _capture_scheduler(scheduler_store, staged)
	if not scheduler.is_ok():
		return scheduler
	var invalid: SaveHeader.Refusal = record_refusal(staged)
	if not invalid.is_ok():
		return invalid
	out.copy_from(staged)
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _capture_economic(store: CommandsScript, staged: Record) -> SaveHeader.Refusal:
	"""Read `commands.gd`'s pending window, its sequence allocator and its payload arena."""
	staged.economic_count = store.pending_count()
	staged.economic_next_sequence_high = store.next_sequence_high()
	staged.economic_next_sequence_low = store.next_sequence_low()
	var scratch: CommandsScript.Command = CommandsScript.Command.new()
	for position: int in staged.economic_count:
		if not store.read_into(position, scratch):
			return SaveHeader.Refusal.new(REFUSE_STORE_REFUSED,
				"the command queue refused position %d: %s" % [position, store.last_refusal()])
		_assign_economic_row(staged, position, scratch)
	staged.payload_used = store.payload_used()
	var rebuild: SaveHeader.Refusal = arena_rebuild_refusal(staged)
	if not rebuild.is_ok():
		return rebuild
	return _capture_payload(store, staged)


static func _assign_economic_row(staged: Record, row: int,
		command: CommandsScript.Command) -> void:
	"""Copy one read command into the Record's fifteen columns, in declared ordinal order 4..18."""
	staged.execute_tick[row] = command.execute_tick
	staged.player_id[row] = command.player_id
	staged.sequence_low[row] = command.sequence_low
	staged.sequence_high[row] = command.sequence_high
	staged.kind[row] = command.kind
	staged.target_slot[row] = command.target_slot
	staged.target_generation[row] = command.target_generation
	staged.goal_x[row] = command.goal_x
	staged.goal_z[row] = command.goal_z
	staged.arg0[row] = command.arg0
	staged.arg1[row] = command.arg1
	staged.payload_offset[row] = command.payload_offset
	staged.payload_length[row] = command.payload_length
	staged.flags[row] = command.flags
	staged.reserved_zero[row] = command.reserved_zero


static func _capture_payload(store: CommandsScript, staged: Record) -> SaveHeader.Refusal:
	"""Rebuild the arena as the live spans verbatim and every other byte zero.

	`arena_rebuild_refusal()` has already proved the spans tile `[0, payload_used)` contiguously
	in queue order, so concatenating each command's bytes reproduces the used prefix exactly --
	and the zero tail is ARCH-SAVE-002's "encode zero for unused payload", not an invention.
	"""
	var arena: PackedByteArray = PackedByteArray()
	var scratch: PackedByteArray = PackedByteArray()
	scratch.resize(_longest_payload(staged))
	var command: CommandsScript.Command = CommandsScript.Command.new()
	for position: int in staged.economic_count:
		store.read_into(position, command)
		if not store.read_payload_into(command, scratch):
			return SaveHeader.Refusal.new(REFUSE_STORE_REFUSED,
				"the command queue refused the payload of position %d: %s"
					% [position, store.last_refusal()])
		arena.append_array(scratch.slice(0, command.payload_length))
	var tail: PackedByteArray = PackedByteArray()
	tail.resize(PAYLOAD_ARENA_BYTES - arena.size())
	tail.fill(0)
	arena.append_array(tail)
	staged.payload = arena
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _longest_payload(staged: Record) -> int:
	"""The longest pending payload, which is the only scratch buffer a capture needs."""
	var longest: int = 0
	for position: int in staged.economic_count:
		longest = maxi(longest, staged.payload_length[position])
	return longest


static func _capture_scheduler(store: SchedulerEventsScript,
		staged: Record) -> SaveHeader.Refusal:
	"""Read `scheduler_events.gd`'s pending window and its 32-byte control block.

	The stored head is the CANONICAL 0, never the live ring head: the contract requires it and
	`restore_extension()` refuses anything else.
	"""
	staged.scheduler_head = 0
	staged.scheduler_count = store.pending_count()
	staged.scheduler_next_sequence_low = store.next_sequence_low()
	staged.scheduler_next_sequence_high = store.next_sequence_high()
	staged.scheduler_last_applied_low = store.last_applied_sequence_low()
	staged.scheduler_last_applied_high = store.last_applied_sequence_high()
	staged.scheduler_last_drained_boundary = store.last_drained_boundary()
	var scratch: SchedulerEventsScript.Event = SchedulerEventsScript.Event.new()
	for position: int in staged.scheduler_count:
		if not store.read_into(position, scratch):
			return SaveHeader.Refusal.new(REFUSE_STORE_REFUSED,
				"the scheduler queue refused position %d: %s" % [position, store.last_refusal()])
		staged.boundary_tick[position] = scratch.boundary_tick
		staged.event_sequence_low[position] = scratch.sequence_low
		staged.event_sequence_high[position] = scratch.sequence_high
		staged.event_kind[position] = scratch.kind
		staged.event_reason[position] = scratch.reason
		staged.event_value[position] = scratch.value
		staged.event_reserved[position] = scratch.reserved
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


# --- encode -------------------------------------------------------------------------------------------

static func encode_record(record: Record, out: EncodeResult) -> bool:
	"""Materialise a whole validated section 12 into one buffer.

	The record bodies come from their OWNERS' encoders (`encode_command_into()`,
	`encode_event_into()`) and the prefix from `encode_section_prefix_into()`, so §8.1's 64-byte
	layout and the contract's 32-byte layout exist in exactly one place each.
	"""
	var invalid: SaveHeader.Refusal = record_refusal(record)
	if not invalid.is_ok():
		return out.refuse(invalid.code, invalid.detail)
	var buffer: PackedByteArray = PackedByteArray()
	buffer.resize(section_byte_length(record))
	buffer.fill(0)
	if not SchedulerEventsScript.encode_section_prefix_into(buffer, 0, record.economic_count,
			record.payload_used, record.scheduler_count, record.economic_next_sequence_low,
			record.economic_next_sequence_high):
		return out.refuse(REFUSE_ENCODE_FAILED, "the section 12 prefix writer refused")
	if not _write_economic_into(record, buffer, 0):
		return out.refuse(REFUSE_ENCODE_FAILED, "an economic record writer refused")
	if not _write_extension_into(record, buffer,
			extension_offset_of(record.economic_count, record.payload_used)):
		return out.refuse(REFUSE_ENCODE_FAILED, "the SCHQ0001 writer refused")
	return out.succeed(buffer)


static func _write_economic_into(record: Record, buffer: PackedByteArray, base: int) -> bool:
	"""Write the E 64-byte records in canonical order, then the P arena bytes after them."""
	var command: CommandsScript.Command = CommandsScript.Command.new()
	for index: int in record.economic_count:
		_fill_command(record, index, command)
		if not CommandsScript.encode_command_into(command, buffer,
				base + economic_record_offset(index)):
			return false
	var arena_base: int = base + payload_offset_of(record.economic_count)
	for index: int in record.payload_used:
		buffer[arena_base + index] = record.payload[index]
	return true


static func _fill_command(record: Record, row: int, out: CommandsScript.Command) -> void:
	"""Fill a caller-owned Command from the Record's columns. The exact inverse of the capture."""
	out.execute_tick = record.execute_tick[row]
	out.player_id = record.player_id[row]
	out.sequence_low = record.sequence_low[row]
	out.sequence_high = record.sequence_high[row]
	out.kind = record.kind[row]
	out.target_slot = record.target_slot[row]
	out.target_generation = record.target_generation[row]
	out.goal_x = record.goal_x[row]
	out.goal_z = record.goal_z[row]
	out.arg0 = record.arg0[row]
	out.arg1 = record.arg1[row]
	out.payload_offset = record.payload_offset[row]
	out.payload_length = record.payload_length[row]
	out.flags = record.flags[row]
	out.reserved_zero = record.reserved_zero[row]


static func _write_extension_into(record: Record, buffer: PackedByteArray, at: int) -> bool:
	"""Write the whole `SCHQ0001` subsection: tag, version, length, control block, then records.

	One writer, used by `encode_record()` AND by `apply()` to build the bytes
	`scheduler_events.gd::restore_extension()` consumes, so the save and the restore can never
	disagree about what this subsection is.
	"""
	if at < 0 or buffer.size() < at + extension_byte_length(record.scheduler_count):
		return false
	for index: int in SECTION_TAG_BYTES:
		buffer.encode_u8(at + index, SECTION_TAG.unicode_at(index))
	buffer.encode_u32(at + SchedulerEventsScript.OFFSET_EXTENSION_SCHEMA_VERSION,
		EXTENSION_SCHEMA_VERSION)
	buffer.encode_u32(at + SchedulerEventsScript.OFFSET_EXTENSION_PAYLOAD_LENGTH,
		CONTROL_BYTES + SCHEDULER_RECORD_BYTES * record.scheduler_count)
	_write_control_into(record, buffer, at + EXTENSION_HEADER_BYTES)
	var event: SchedulerEventsScript.Event = SchedulerEventsScript.Event.new()
	for index: int in record.scheduler_count:
		_fill_event(record, index, event)
		if not SchedulerEventsScript.encode_event_into(event, buffer,
				at + EXTENSION_FIXED_BYTES + SCHEDULER_RECORD_BYTES * index):
			return false
	return true


static func _write_control_into(record: Record, buffer: PackedByteArray, at: int) -> void:
	"""Write the 32-byte queue control block, with the contract's canonical head 0."""
	buffer.encode_s32(at + SchedulerEventsScript.OFFSET_CONTROL_HEAD, 0)
	buffer.encode_s32(at + SchedulerEventsScript.OFFSET_CONTROL_COUNT, record.scheduler_count)
	buffer.encode_u32(at + SchedulerEventsScript.OFFSET_CONTROL_NEXT_SEQUENCE_LOW,
		record.scheduler_next_sequence_low)
	buffer.encode_u32(at + SchedulerEventsScript.OFFSET_CONTROL_NEXT_SEQUENCE_HIGH,
		record.scheduler_next_sequence_high)
	buffer.encode_s64(at + SchedulerEventsScript.OFFSET_CONTROL_LAST_DRAINED_BOUNDARY,
		record.scheduler_last_drained_boundary)
	buffer.encode_u32(at + SchedulerEventsScript.OFFSET_CONTROL_LAST_APPLIED_SEQUENCE_LOW,
		record.scheduler_last_applied_low)
	buffer.encode_u32(at + SchedulerEventsScript.OFFSET_CONTROL_LAST_APPLIED_SEQUENCE_HIGH,
		record.scheduler_last_applied_high)


static func _fill_event(record: Record, row: int, out: SchedulerEventsScript.Event) -> void:
	"""Fill a caller-owned Event from the Record's columns. The exact inverse of the capture."""
	out.boundary_tick = record.boundary_tick[row]
	out.sequence_low = record.event_sequence_low[row]
	out.sequence_high = record.event_sequence_high[row]
	out.kind = record.event_kind[row]
	out.reason = record.event_reason[row]
	out.value = record.event_value[row]
	out.reserved = record.event_reserved[row]


static func extension_bytes_of(record: Record) -> PackedByteArray:
	"""The `SCHQ0001` subsection alone, as `restore_extension()` and its validator take it.

	Empty only when the writer refused, which `record_refusal()` has already made impossible;
	`apply()` still tests it rather than assuming, because an empty buffer would otherwise be
	handed to the owner as a truncated subsection.
	"""
	var buffer: PackedByteArray = PackedByteArray()
	buffer.resize(extension_byte_length(record.scheduler_count))
	buffer.fill(0)
	if not _write_extension_into(record, buffer, 0):
		return PackedByteArray()
	return buffer


# --- decode -------------------------------------------------------------------------------------------

static func extent_refusal(bytes: PackedByteArray, offset: int) -> SaveHeader.Refusal:
	"""Prove a whole section 12 is readable at `offset`, reading the prefix to learn its length.

	Public because it is the PRIMARY gate and must be testable on its own, exactly as
	`save_section_directory.gd::extent_refusal()` is. Section 12 is variable length, so the gate
	has to read E, P and X first -- and it bounds all three (SAVE-LAYOUT-R01: "validate count,
	checked multiplication, remaining bytes ... before allocating or writing a store") before the
	total is computed, so the multiplication cannot overflow.
	"""
	if offset < 0:
		return SaveHeader.Refusal.new(REFUSE_NEGATIVE_OFFSET, "offset %d is negative" % offset)
	if bytes.size() < PREFIX_BYTES or offset > bytes.size() - PREFIX_BYTES:
		return SaveHeader.Refusal.new(REFUSE_TRUNCATED,
			"section 12 needs at least %d prefix bytes at offset %d, buffer holds %d"
				% [PREFIX_BYTES, offset, bytes.size()])
	var header: SaveHeader.Refusal = _prefix_shape_refusal(bytes, offset)
	if not header.is_ok():
		return header
	var counts: PackedInt32Array = _prefix_counts(bytes, offset)
	var total: int = SchedulerEventsScript.section_twelve_length(counts[0], counts[1], counts[2])
	if bytes.size() < total or offset > bytes.size() - total:
		return SaveHeader.Refusal.new(REFUSE_TRUNCATED,
			"section 12 needs %d bytes at offset %d, buffer holds %d"
				% [total, offset, bytes.size()])
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _prefix_shape_refusal(bytes: PackedByteArray, offset: int) -> SaveHeader.Refusal:
	"""Check the prefix's schema word, its three counts and the `48 + 32*S` extension length."""
	var scalar: SaveCodec.Scalar = SaveCodec.Scalar.new()
	SaveCodec.read_u32_at(bytes, offset + OFFSET_PREFIX_SECTION_SCHEMA, scalar)
	if scalar.value != SECTION_SCHEMA_VERSION:
		return SaveHeader.Refusal.new(REFUSE_SECTION_SCHEMA,
			"section 12 declares schema %d, not the supported %d"
				% [scalar.value, SECTION_SCHEMA_VERSION])
	var counts: PackedInt32Array = _prefix_counts(bytes, offset)
	if counts[2] < 0:
		return SaveHeader.Refusal.new(REFUSE_EXTENSION_LENGTH,
			"scheduler_extension_bytes is not %d + 32*S" % EXTENSION_FIXED_BYTES)
	return bound_refusal(counts[0], counts[1], counts[2])


static func _prefix_counts(bytes: PackedByteArray, offset: int) -> PackedInt32Array:
	"""`[E, P, S]` read straight off the prefix, with S recovered from X. Unvalidated."""
	var scalar: SaveCodec.Scalar = SaveCodec.Scalar.new()
	SaveCodec.read_u32_at(bytes, offset + OFFSET_PREFIX_ECONOMIC_COUNT, scalar)
	var economic: int = scalar.value
	SaveCodec.read_u32_at(bytes, offset + OFFSET_PREFIX_PAYLOAD_USED, scalar)
	var used: int = scalar.value
	SaveCodec.read_u32_at(bytes, offset + OFFSET_PREFIX_EXTENSION_BYTES, scalar)
	return PackedInt32Array([economic, used, scheduler_count_of_extension_bytes(scalar.value)])


static func bound_refusal(economic_count: int, payload_used: int,
		scheduler_count: int) -> SaveHeader.Refusal:
	"""The contract's "Require E <= 4096, P <= 1048576, S <= 256", naming which one failed.

	The bound itself is `scheduler_events.gd::section_twelve_refusal()` so the three limits live in
	one place; this only translates its two generic codes into a refusal that says which of the
	three counts was wrong, because "SECTION_COUNT" alone cannot tell E from S.
	"""
	if SchedulerEventsScript.section_twelve_refusal(economic_count, payload_used,
			scheduler_count) == REFUSE_NONE:
		return SaveHeader.Refusal.new(REFUSE_NONE, "")
	if economic_count < 0 or economic_count > SchedulerEventsScript.MAX_ECONOMIC_RECORDS:
		return SaveHeader.Refusal.new(REFUSE_ECONOMIC_COUNT,
			"E is %d, outside 0..%d"
				% [economic_count, SchedulerEventsScript.MAX_ECONOMIC_RECORDS])
	if payload_used < 0 or payload_used > SchedulerEventsScript.MAX_ECONOMIC_PAYLOAD_BYTES:
		return SaveHeader.Refusal.new(REFUSE_PAYLOAD_USED,
			"P is %d, outside 0..%d"
				% [payload_used, SchedulerEventsScript.MAX_ECONOMIC_PAYLOAD_BYTES])
	return SaveHeader.Refusal.new(REFUSE_SCHEDULER_COUNT,
		"S is %d, outside 0..%d" % [scheduler_count, SCHEDULER_CAPACITY])


static func section_length_refusal(byte_length: int, record: Record) -> SaveHeader.Refusal:
	"""Check a descriptor's declared section length against this Record's computed length.

	SAVE-R09-004 requires exact block consumption and no trailing bytes. Section 12 has no fixed
	length, so the check is against `72 + 64*E + P + 32*S` for the state actually held.
	"""
	var expected: int = section_byte_length(record)
	if byte_length != expected:
		return SaveHeader.Refusal.new(REFUSE_LENGTH,
			"section 12 declares %d bytes, not the %d this state occupies"
				% [byte_length, expected])
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func decode_into(bytes: PackedByteArray, offset: int, out: Record) -> SaveHeader.Refusal:
	"""Decode section 12 from `offset`, validating everything before `out` is written at all.

	Allocate before consume (decision 0059): the extent is proved, the prefix and both owners'
	records land in a LOCAL Record, and every cross-column invariant runs against that local. A
	FULL-LENGTH section carrying an out-of-order key, a nonzero `reserved`, an overlapping payload
	span or arena garbage therefore leaves `out` byte-identical -- validate-then-commit.
	"""
	var extent: SaveHeader.Refusal = extent_refusal(bytes, offset)
	if not extent.is_ok():
		return extent
	var parsed: Record = Record.new()
	var counts: PackedInt32Array = _prefix_counts(bytes, offset)
	_read_prefix(bytes, offset, counts, parsed)
	_read_economic(bytes, offset, parsed)
	var extension: SaveHeader.Refusal = _read_extension(bytes, offset, parsed)
	if not extension.is_ok():
		return extension
	var invalid: SaveHeader.Refusal = record_refusal(parsed)
	if not invalid.is_ok():
		return invalid
	out.copy_from(parsed)
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _read_prefix(bytes: PackedByteArray, offset: int, counts: PackedInt32Array,
		parsed: Record) -> void:
	"""Take the prefix's counts and the economic sequence allocator into the Record."""
	var scalar: SaveCodec.Scalar = SaveCodec.Scalar.new()
	parsed.economic_count = counts[0]
	parsed.payload_used = counts[1]
	parsed.scheduler_count = counts[2]
	SaveCodec.read_u32_at(bytes, offset + OFFSET_PREFIX_NEXT_SEQUENCE_LOW, scalar)
	parsed.economic_next_sequence_low = scalar.value
	SaveCodec.read_u32_at(bytes, offset + OFFSET_PREFIX_NEXT_SEQUENCE_HIGH, scalar)
	parsed.economic_next_sequence_high = scalar.value


static func _read_economic(bytes: PackedByteArray, offset: int, parsed: Record) -> void:
	"""Read the E 64-byte records and the P arena bytes. Structural; nothing is judged here."""
	var command: CommandsScript.Command = CommandsScript.Command.new()
	for index: int in parsed.economic_count:
		CommandsScript.decode_record_into(bytes, offset + economic_record_offset(index), command)
		_assign_economic_row(parsed, index, command)
	var base: int = offset + payload_offset_of(parsed.economic_count)
	var arena: PackedByteArray = bytes.slice(base, base + parsed.payload_used)
	var tail: PackedByteArray = PackedByteArray()
	tail.resize(PAYLOAD_ARENA_BYTES - parsed.payload_used)
	tail.fill(0)
	arena.append_array(tail)
	parsed.payload = arena


static func _read_extension(bytes: PackedByteArray, offset: int,
		parsed: Record) -> SaveHeader.Refusal:
	"""Read the `SCHQ0001` tag, header, control block and S records into the Record."""
	var at: int = offset + extension_offset_of(parsed.economic_count, parsed.payload_used)
	for index: int in SECTION_TAG_BYTES:
		if bytes.decode_u8(at + index) != SECTION_TAG.unicode_at(index):
			return SaveHeader.Refusal.new(REFUSE_EXTENSION_TAG,
				"byte %d of the extension tag is not `%s`" % [index, SECTION_TAG])
	if bytes.decode_u32(at + SchedulerEventsScript.OFFSET_EXTENSION_SCHEMA_VERSION) \
			!= EXTENSION_SCHEMA_VERSION:
		return SaveHeader.Refusal.new(REFUSE_EXTENSION_VERSION,
			"the SCHQ0001 schema version is not the supported %d" % EXTENSION_SCHEMA_VERSION)
	if bytes.decode_u32(at + SchedulerEventsScript.OFFSET_EXTENSION_PAYLOAD_LENGTH) \
			!= CONTROL_BYTES + SCHEDULER_RECORD_BYTES * parsed.scheduler_count:
		return SaveHeader.Refusal.new(REFUSE_EXTENSION_LENGTH,
			"the SCHQ0001 payload length disagrees with the prefix's scheduler_extension_bytes")
	_read_control(bytes, at + EXTENSION_HEADER_BYTES, parsed)
	_read_events(bytes, at + EXTENSION_FIXED_BYTES, parsed)
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _read_control(bytes: PackedByteArray, at: int, parsed: Record) -> void:
	"""Read the 32-byte queue control block. The head is read, not assumed, so it can be refused."""
	parsed.scheduler_head = bytes.decode_s32(at + SchedulerEventsScript.OFFSET_CONTROL_HEAD)
	parsed.scheduler_next_sequence_low = bytes.decode_u32(
		at + SchedulerEventsScript.OFFSET_CONTROL_NEXT_SEQUENCE_LOW)
	parsed.scheduler_next_sequence_high = bytes.decode_u32(
		at + SchedulerEventsScript.OFFSET_CONTROL_NEXT_SEQUENCE_HIGH)
	parsed.scheduler_last_drained_boundary = bytes.decode_s64(
		at + SchedulerEventsScript.OFFSET_CONTROL_LAST_DRAINED_BOUNDARY)
	parsed.scheduler_last_applied_low = bytes.decode_u32(
		at + SchedulerEventsScript.OFFSET_CONTROL_LAST_APPLIED_SEQUENCE_LOW)
	parsed.scheduler_last_applied_high = bytes.decode_u32(
		at + SchedulerEventsScript.OFFSET_CONTROL_LAST_APPLIED_SEQUENCE_HIGH)


static func _read_events(bytes: PackedByteArray, at: int, parsed: Record) -> void:
	"""Read the S 32-byte scheduler records into the Record's seven columns."""
	var event: SchedulerEventsScript.Event = SchedulerEventsScript.Event.new()
	for index: int in parsed.scheduler_count:
		SchedulerEventsScript.decode_event_into(bytes,
			at + SCHEDULER_RECORD_BYTES * index, event)
		parsed.boundary_tick[index] = event.boundary_tick
		parsed.event_sequence_low[index] = event.sequence_low
		parsed.event_sequence_high[index] = event.sequence_high
		parsed.event_kind[index] = event.kind
		parsed.event_reason[index] = event.reason
		parsed.event_value[index] = event.value
		parsed.event_reserved[index] = event.reserved


# --- validation --------------------------------------------------------------------------------------

static func record_refusal(record: Record) -> SaveHeader.Refusal:
	"""Every section 12 rule this module owns, in one gate shared by capture, encode and decode.

	It deliberately stops short of the SEMANTIC envelope rules both owners keep to themselves --
	`commands.gd::envelope_refusal()` needs the live directory, and
	`scheduler_events.gd::event_refusal()` owns reason ownership and speed selectability. `apply()`
	runs both of those before it writes. Two validators, pointing one way, as §3 already does.
	"""
	var shape: SaveHeader.Refusal = _shape_refusal(record)
	if not shape.is_ok():
		return shape
	var scalars: SaveHeader.Refusal = _scalar_refusal(record)
	if not scalars.is_ok():
		return scalars
	var economic: SaveHeader.Refusal = _economic_refusal(record)
	if not economic.is_ok():
		return economic
	var payload: SaveHeader.Refusal = _payload_refusal(record)
	if not payload.is_ok():
		return payload
	var scheduler: SaveHeader.Refusal = _scheduler_refusal(record)
	if not scheduler.is_ok():
		return scheduler
	return _ring_tail_refusal(record)


static func _shape_refusal(record: Record) -> SaveHeader.Refusal:
	"""Every column must be exactly its ring capacity long before anything indexes into it."""
	if record.execute_tick.size() != ECONOMIC_CAPACITY:
		return SaveHeader.Refusal.new(REFUSE_RECORD_SHAPE,
			"_execute_tick holds %d rows, not %d"
				% [record.execute_tick.size(), ECONOMIC_CAPACITY])
	for column: PackedInt32Array in record.economic_columns():
		if column.size() != ECONOMIC_CAPACITY:
			return SaveHeader.Refusal.new(REFUSE_RECORD_SHAPE,
				"an economic column holds %d rows, not %d" % [column.size(), ECONOMIC_CAPACITY])
	if record.payload.size() != PAYLOAD_ARENA_BYTES:
		return SaveHeader.Refusal.new(REFUSE_RECORD_SHAPE,
			"the arena holds %d bytes, not %d" % [record.payload.size(), PAYLOAD_ARENA_BYTES])
	if record.boundary_tick.size() != SCHEDULER_CAPACITY:
		return SaveHeader.Refusal.new(REFUSE_RECORD_SHAPE,
			"_boundary_tick holds %d rows, not %d"
				% [record.boundary_tick.size(), SCHEDULER_CAPACITY])
	for column: PackedInt32Array in record.scheduler_columns():
		if column.size() != SCHEDULER_CAPACITY:
			return SaveHeader.Refusal.new(REFUSE_RECORD_SHAPE,
				"a scheduler column holds %d rows, not %d"
					% [column.size(), SCHEDULER_CAPACITY])
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _scalar_refusal(record: Record) -> SaveHeader.Refusal:
	"""The three counts, the canonical head and all four u32 sequence allocators."""
	var bound: SaveHeader.Refusal = bound_refusal(record.economic_count, record.payload_used,
		record.scheduler_count)
	if not bound.is_ok():
		return bound
	if record.scheduler_head != 0:
		return SaveHeader.Refusal.new(REFUSE_HEAD_NOT_CANONICAL,
			"the stored scheduler head is %d; the contract stores the canonical 0"
				% record.scheduler_head)
	if record.scheduler_last_drained_boundary < NO_PRIOR_DRAIN:
		return SaveHeader.Refusal.new(REFUSE_CONTROL,
			"last_drained_boundary %d is below %d"
				% [record.scheduler_last_drained_boundary, NO_PRIOR_DRAIN])
	return _sequence_range_refusal(record)


static func _sequence_range_refusal(record: Record) -> SaveHeader.Refusal:
	"""All four sequence allocators are u32 values 0..4294967295, never i32 bit spellings.

	This is the sign trap's other face: the COLUMNS hold i32 bits and the ALLOCATORS hold unsigned
	values, because that is what `restore_sequence()` takes and what the prefix's u32 carries. A
	negative here would round-trip as 4294967295-something and reorder a whole session.
	"""
	var names: PackedStringArray = PackedStringArray(["economic next_sequence_high",
		"economic next_sequence_low", "scheduler next_sequence_low",
		"scheduler next_sequence_high", "scheduler last_applied_low",
		"scheduler last_applied_high"])
	var values: PackedInt64Array = PackedInt64Array([record.economic_next_sequence_high,
		record.economic_next_sequence_low, record.scheduler_next_sequence_low,
		record.scheduler_next_sequence_high, record.scheduler_last_applied_low,
		record.scheduler_last_applied_high])
	for index: int in values.size():
		if values[index] < 0 or values[index] > U32_MAX:
			return SaveHeader.Refusal.new(REFUSE_SEQUENCE_RANGE,
				"%s is %d, outside 0..%d" % [names[index], values[index], U32_MAX])
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _economic_refusal(record: Record) -> SaveHeader.Refusal:
	"""Every pending command's fields, and ARCH-CMD-001's strictly increasing ordering key."""
	for row: int in record.economic_count:
		var invalid: SaveHeader.Refusal = _economic_row_refusal(record, row)
		if not invalid.is_ok():
			return invalid
		if row == 0:
			continue
		if CommandsScript.compare_key_parts(record.execute_tick[row - 1],
				record.player_id[row - 1], record.sequence_high[row - 1],
				record.sequence_low[row - 1], record.execute_tick[row], record.player_id[row],
				record.sequence_high[row], record.sequence_low[row]) >= 0:
			return SaveHeader.Refusal.new(REFUSE_KEY_ORDER,
				("records %d and %d are not in strictly increasing ARCH-CMD-001 key order; the "
					+ "queue would reorder on load") % [row - 1, row])
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _economic_row_refusal(record: Record, row: int) -> SaveHeader.Refusal:
	"""One pending command's player, kind, flags, reserved word, target shape and payload span."""
	if record.player_id[row] != RELEASE_ONE_PLAYER_ID:
		return SaveHeader.Refusal.new(REFUSE_PLAYER_ID,
			"record %d carries player %d; release 1 has only player %d"
				% [row, record.player_id[row], RELEASE_ONE_PLAYER_ID])
	if record.kind[row] < 0 or record.kind[row] >= CatalogScript.COMMAND_KIND.size():
		return SaveHeader.Refusal.new(REFUSE_UNKNOWN_KIND,
			"record %d carries kind %d, outside ARCH-CMD-003's %d compiled ids"
				% [row, record.kind[row], CatalogScript.COMMAND_KIND.size()])
	if record.flags[row] != 0:
		return SaveHeader.Refusal.new(REFUSE_FLAGS_UNDEFINED,
			"record %d carries flags %d; no specification defines a bit"
				% [row, record.flags[row]])
	if record.reserved_zero[row] != 0:
		return SaveHeader.Refusal.new(REFUSE_RESERVED_NONZERO,
			"record %d carries reserved_zero %d" % [row, record.reserved_zero[row]])
	if record.target_slot[row] == NULL_SLOT \
			and record.target_generation[row] != NULL_GENERATION:
		return SaveHeader.Refusal.new(REFUSE_TARGET_MALFORMED,
			"record %d names no entity but carries generation %d"
				% [row, record.target_generation[row]])
	if record.target_slot[row] < NULL_SLOT:
		return SaveHeader.Refusal.new(REFUSE_TARGET_MALFORMED,
			"record %d carries target slot %d" % [row, record.target_slot[row]])
	return _span_shape_refusal(record, row)


static func _span_shape_refusal(record: Record, row: int) -> SaveHeader.Refusal:
	"""One pending command's `(payload_offset, payload_length)` against the used prefix."""
	var offset: int = record.payload_offset[row]
	var length: int = record.payload_length[row]
	if offset < 0 or length < 0:
		return SaveHeader.Refusal.new(REFUSE_PAYLOAD_SPAN,
			"record %d spans (%d, %d); neither may be negative" % [row, offset, length])
	if offset > record.payload_used or length > record.payload_used - offset:
		return SaveHeader.Refusal.new(REFUSE_PAYLOAD_SPAN,
			"record %d spans (%d, %d), outside the %d-byte used prefix"
				% [row, offset, length, record.payload_used])
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _payload_refusal(record: Record) -> SaveHeader.Refusal:
	"""No two pending spans overlap, and every arena byte no span covers is zero.

	The second half is what keeps a drained command's leftover bytes out of the file: they are
	inside the used prefix, they differ between two observationally identical worlds, and
	ARCH-SAVE-002 says "encode zero for unused payload". The spans are sorted as packed keys
	`offset * 2097152 + length`, which is exact because both are bounded by 1048576 < 2097152.
	"""
	var spans: PackedInt64Array = _sorted_spans(record)
	var cursor: int = 0
	for index: int in spans.size():
		var offset: int = spans[index] / 2097152
		var length: int = spans[index] % 2097152
		if offset < cursor:
			return SaveHeader.Refusal.new(REFUSE_PAYLOAD_OVERLAP,
				"a pending payload span starts at %d, inside a span ending at %d"
					% [offset, cursor])
		if not _is_zero_run(record.payload, cursor, offset):
			return SaveHeader.Refusal.new(REFUSE_PAYLOAD_GARBAGE,
				"arena bytes [%d, %d) belong to no pending command and are not zero"
					% [cursor, offset])
		cursor = offset + length
	if not _is_zero_run(record.payload, cursor, PAYLOAD_ARENA_BYTES):
		return SaveHeader.Refusal.new(REFUSE_PAYLOAD_GARBAGE,
			"arena bytes [%d, %d) belong to no pending command and are not zero"
				% [cursor, PAYLOAD_ARENA_BYTES])
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _sorted_spans(record: Record) -> PackedInt64Array:
	"""The pending payload spans as `offset * 2097152 + length`, sorted ascending by offset."""
	var spans: PackedInt64Array = PackedInt64Array()
	for row: int in record.economic_count:
		spans.append(record.payload_offset[row] * 2097152 + record.payload_length[row])
	spans.sort()
	return spans


static func _is_zero_run(bytes: PackedByteArray, start: int, end: int) -> bool:
	"""True when `[start, end)` is entirely zero. One C++ slice and one C++ count, no loop."""
	if end <= start:
		return true
	return bytes.slice(start, end).count(0) == end - start


static func _scheduler_refusal(record: Record) -> SaveHeader.Refusal:
	"""Every pending event's kind and padding, one shared boundary, and strict sequence order."""
	for row: int in record.scheduler_count:
		if record.event_kind[row] < 0 or record.event_kind[row] >= SCHEDULER_KIND_COUNT:
			return SaveHeader.Refusal.new(REFUSE_UNKNOWN_KIND,
				"event %d carries kind %d, outside this queue's %d"
					% [row, record.event_kind[row], SCHEDULER_KIND_COUNT])
		if record.event_reserved[row] != 0:
			return SaveHeader.Refusal.new(REFUSE_RESERVED_NONZERO,
				"event %d carries reserved %d" % [row, record.event_reserved[row]])
		if record.boundary_tick[row] != record.boundary_tick[0]:
			return SaveHeader.Refusal.new(REFUSE_BOUNDARY_MISMATCH,
				"event %d waits at boundary %d, event 0 at %d"
					% [row, record.boundary_tick[row], record.boundary_tick[0]])
	return _scheduler_sequence_refusal(record)


static func _scheduler_sequence_refusal(record: Record) -> SaveHeader.Refusal:
	"""last_applied precedes every pending sequence, which strictly increases, below next.

	Every comparison goes through `compare_sequence()`, which masks both words first: a signed
	read would put 0x80000000 before 0x7fffffff and silently reverse two events.
	"""
	var high: int = record.scheduler_last_applied_high
	var low: int = record.scheduler_last_applied_low
	for row: int in record.scheduler_count:
		var row_high: int = SchedulerEventsScript.to_uint32(record.event_sequence_high[row])
		var row_low: int = SchedulerEventsScript.to_uint32(record.event_sequence_low[row])
		if row_high == 0 and row_low == 0:
			return SaveHeader.Refusal.new(REFUSE_SEQUENCE_ORDER,
				"event %d carries the exhausted sentinel (0, 0)" % row)
		if SchedulerEventsScript.compare_sequence(row_high, row_low, high, low) <= 0:
			return SaveHeader.Refusal.new(REFUSE_SEQUENCE_ORDER,
				"event %d's sequence does not exceed the one before it" % row)
		high = row_high
		low = row_low
	if record.scheduler_count == 0:
		return SaveHeader.Refusal.new(REFUSE_NONE, "")
	if record.scheduler_next_sequence_high == 0 and record.scheduler_next_sequence_low == 0:
		return SaveHeader.Refusal.new(REFUSE_NONE, "")
	if SchedulerEventsScript.compare_sequence(record.scheduler_next_sequence_high,
			record.scheduler_next_sequence_low, high, low) <= 0:
		return SaveHeader.Refusal.new(REFUSE_SEQUENCE_ORDER,
			"the next scheduler sequence does not exceed the last admitted one")
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _ring_tail_refusal(record: Record) -> SaveHeader.Refusal:
	"""Past both live windows every column holds its DECLARED canonical unused value.

	This is the ring-garbage gate. Nothing beyond `_count` positions from `_head` means anything in
	either queue, so a Record that carried a drained command's leftover row would make two
	observationally identical worlds encode differently. Refusing it here means a capture that
	read raw rows instead of queue positions cannot round-trip.
	"""
	var economic: SaveHeader.Refusal = _economic_tail_refusal(record)
	if not economic.is_ok():
		return economic
	var start: int = record.scheduler_count
	if record.boundary_tick.slice(start, SCHEDULER_CAPACITY).count(0) \
			!= SCHEDULER_CAPACITY - start:
		return SaveHeader.Refusal.new(REFUSE_RING_TAIL_GARBAGE,
			"_boundary_tick holds a nonzero value past the %d pending events" % start)
	for column: PackedInt32Array in record.scheduler_columns():
		if column.slice(start, SCHEDULER_CAPACITY).count(0) != SCHEDULER_CAPACITY - start:
			return SaveHeader.Refusal.new(REFUSE_RING_TAIL_GARBAGE,
				"a scheduler column holds a nonzero value past the %d pending events" % start)
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _economic_tail_refusal(record: Record) -> SaveHeader.Refusal:
	"""The economic ring's tail: `_target_slot` is -1, `_target_generation` 0, all else 0."""
	var start: int = record.economic_count
	var rows: int = ECONOMIC_CAPACITY - start
	if record.execute_tick.slice(start, ECONOMIC_CAPACITY).count(0) != rows:
		return SaveHeader.Refusal.new(REFUSE_RING_TAIL_GARBAGE,
			"_execute_tick holds a nonzero value past the %d pending commands" % start)
	if record.target_slot.slice(start, ECONOMIC_CAPACITY).count(NULL_SLOT) != rows:
		return SaveHeader.Refusal.new(REFUSE_RING_TAIL_GARBAGE,
			"_target_slot holds a value other than %d past the %d pending commands"
				% [NULL_SLOT, start])
	var columns: Array[PackedInt32Array] = record.economic_columns()
	for index: int in columns.size():
		if index == 4:
			continue
		if columns[index].slice(start, ECONOMIC_CAPACITY).count(0) != rows:
			return SaveHeader.Refusal.new(REFUSE_RING_TAIL_GARBAGE,
				"economic column %s holds a nonzero value past the %d pending commands"
					% [FIELD_KEYS_COMMANDS[FIELD_COMMANDS_FIRST_RECORD + 1 + index], start])
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func arena_rebuild_refusal(record: Record) -> SaveHeader.Refusal:
	"""Prove `commands.gd`'s bump allocator reproduces this Record's arena exactly. BLOCKER P2.

	`_allocate_payload()` resets the cursor only while the queue is empty, so restoring through
	`admit_stamped_into()` always lays the pending payloads out contiguously from offset 0 in
	canonical order. Any other arena -- a non-zero first offset left by a partial drain -- has no
	public restore path, so it is refused at CAPTURE as well as at apply rather than written into
	a file that cannot be loaded.
	"""
	var cursor: int = 0
	for row: int in record.economic_count:
		if record.payload_offset[row] != cursor:
			return SaveHeader.Refusal.new(REFUSE_ARENA_NOT_REBUILDABLE,
				("record %d sits at arena offset %d, not the %d a restore would give it. "
					+ "commands.gd publishes no arena-base restore; see BLOCKER P2.")
					% [row, record.payload_offset[row], cursor])
		cursor += record.payload_length[row]
	if cursor != record.payload_used:
		return SaveHeader.Refusal.new(REFUSE_ARENA_NOT_REBUILDABLE,
			("the pending payloads occupy %d bytes but the arena cursor is at %d; a restore "
				+ "would leave it at %d. See BLOCKER P2.")
				% [cursor, record.payload_used, cursor])
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


# --- apply ---------------------------------------------------------------------------------------------

static func apply(record: Record, commands_store: CommandsScript,
		scheduler_store: SchedulerEventsScript,
		saved_completed_tick: int) -> SaveHeader.Refusal:
	"""Publish a validated Record into both live queues through their own restore APIs.

	The load half of §12. §1's clock and §3's directory MUST already be restored: every incoming
	tick is checked against `completed_tick()` and every target against the live directory.
	Everything is validated -- this module's rules, the arena rebuild, both stores empty, the
	owners' own validators over every incoming record -- BEFORE the first mutation, so a refusal
	leaves both stores byte-identical (decision 0059).
	"""
	var invalid: SaveHeader.Refusal = record_refusal(record)
	if not invalid.is_ok():
		return invalid
	var rebuild: SaveHeader.Refusal = arena_rebuild_refusal(record)
	if not rebuild.is_ok():
		return rebuild
	var extension: PackedByteArray = extension_bytes_of(record)
	var preflight: SaveHeader.Refusal = _preflight_refusal(record, commands_store,
		scheduler_store, saved_completed_tick, extension)
	if not preflight.is_ok():
		return preflight
	return _commit(record, commands_store, scheduler_store, saved_completed_tick, extension)


static func _preflight_refusal(record: Record, commands_store: CommandsScript,
		scheduler_store: SchedulerEventsScript, saved_completed_tick: int,
		extension: PackedByteArray) -> SaveHeader.Refusal:
	"""Prove both stores are empty and both owners accept every incoming record. Writes nothing."""
	if commands_store.pending_count() != 0:
		return SaveHeader.Refusal.new(REFUSE_STORE_NOT_EMPTY,
			"the command queue already holds %d pending commands"
				% commands_store.pending_count())
	if scheduler_store.pending_count() != 0:
		return SaveHeader.Refusal.new(REFUSE_STORE_NOT_EMPTY,
			"the scheduler queue already holds %d pending events"
				% scheduler_store.pending_count())
	if extension.is_empty():
		return SaveHeader.Refusal.new(REFUSE_ENCODE_FAILED,
			"the SCHQ0001 writer refused to build the subsection this restore needs")
	var owned: StringName = scheduler_store.extension_refusal(extension, 0, saved_completed_tick)
	if owned != REFUSE_NONE:
		return SaveHeader.Refusal.new(REFUSE_STORE_REFUSED,
			"scheduler_events.gd refuses this subsection: %s" % owned)
	return _command_envelope_refusal(record, commands_store)


static func _command_envelope_refusal(record: Record,
		store: CommandsScript) -> SaveHeader.Refusal:
	"""Run `commands.gd`'s own envelope validator over every incoming record. Writes nothing.

	This is where a target `EntityRef` meets the restored directory's generations, which is why
	§3 has to be restored first.
	"""
	var command: CommandsScript.Command = CommandsScript.Command.new()
	var floor_tick: int = store.clock().completed_tick()
	for row: int in record.economic_count:
		_fill_command(record, row, command)
		var refusal: StringName = store.envelope_refusal(command)
		if refusal != CommandsScript.REFUSE_NONE:
			return SaveHeader.Refusal.new(REFUSE_STORE_REFUSED,
				"commands.gd refuses record %d: %s" % [row, refusal])
		if command.execute_tick <= floor_tick:
			return SaveHeader.Refusal.new(REFUSE_STORE_REFUSED,
				"record %d is due at tick %d, at or before the restored completed tick %d"
					% [row, command.execute_tick, floor_tick])
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _commit(record: Record, commands_store: CommandsScript,
		scheduler_store: SchedulerEventsScript, saved_completed_tick: int,
		extension: PackedByteArray) -> SaveHeader.Refusal:
	"""Install both queues, scheduler first, after every gate has passed.

	A refusal here means the owner's validator and this module's disagreed after the preflight
	accepted -- the same divergence `save_section_directory.gd::apply()` reports rather than
	leaving a half-written store unexplained.
	"""
	if not scheduler_store.restore_extension(extension, 0, saved_completed_tick):
		return SaveHeader.Refusal.new(REFUSE_STORE_REFUSED,
			"scheduler_events.gd refused a subsection its own validator accepted: %s"
				% scheduler_store.last_refusal())
	if not commands_store.restore_sequence(record.economic_next_sequence_high,
			record.economic_next_sequence_low):
		return SaveHeader.Refusal.new(REFUSE_STORE_REFUSED,
			"commands.gd refused the restored sequence: %s" % commands_store.last_refusal())
	return _admit_all(record, commands_store)


static func _admit_all(record: Record, store: CommandsScript) -> SaveHeader.Refusal:
	"""Admit every pending command in canonical order, payload bytes and all."""
	var command: CommandsScript.Command = CommandsScript.Command.new()
	var result: CommandsScript.SubmitResult = CommandsScript.SubmitResult.new()
	for row: int in record.economic_count:
		_fill_command(record, row, command)
		command.payload = record.payload.slice(record.payload_offset[row],
			record.payload_offset[row] + record.payload_length[row])
		if not store.admit_stamped_into(command, result):
			return SaveHeader.Refusal.new(REFUSE_STORE_REFUSED,
				"commands.gd refused record %d after accepting it in preflight: %s"
					% [row, result.error])
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


# --- verification against the live stores ---------------------------------------------------------------

static func agrees_with_stores(record: Record, commands_store: CommandsScript,
		scheduler_store: SchedulerEventsScript) -> SaveHeader.Refusal:
	"""Verify a decoded Record against both live queues through their PUBLIC readers.

	Scoped to the public surface on purpose, so it stays a genuinely independent cross-check: a
	test that captured the stores again and compared Records would be comparing `capture_into()`
	with itself.
	"""
	var invalid: SaveHeader.Refusal = record_refusal(record)
	if not invalid.is_ok():
		return invalid
	if commands_store.pending_count() != record.economic_count:
		return SaveHeader.Refusal.new(REFUSE_STORE_REFUSED,
			"the command queue holds %d pending commands, the record %d"
				% [commands_store.pending_count(), record.economic_count])
	if scheduler_store.pending_count() != record.scheduler_count:
		return SaveHeader.Refusal.new(REFUSE_STORE_REFUSED,
			"the scheduler queue holds %d pending events, the record %d"
				% [scheduler_store.pending_count(), record.scheduler_count])
	var economic: SaveHeader.Refusal = _store_economic_refusal(record, commands_store)
	if not economic.is_ok():
		return economic
	return _store_scheduler_refusal(record, scheduler_store)


static func _store_economic_refusal(record: Record,
		store: CommandsScript) -> SaveHeader.Refusal:
	"""Compare every queued command's key, kind and payload span with the Record's."""
	var command: CommandsScript.Command = CommandsScript.Command.new()
	for position: int in record.economic_count:
		store.read_into(position, command)
		if command.execute_tick != record.execute_tick[position] \
				or command.sequence_high != record.sequence_high[position] \
				or command.sequence_low != record.sequence_low[position]:
			return SaveHeader.Refusal.new(REFUSE_KEY_ORDER,
				"queue position %d carries a different ARCH-CMD-001 key than the record"
					% position)
		if command.kind != record.kind[position] \
				or command.payload_length != record.payload_length[position]:
			return SaveHeader.Refusal.new(REFUSE_STORE_REFUSED,
				"queue position %d disagrees with the record on kind or payload length"
					% position)
	if store.payload_used() != record.payload_used:
		return SaveHeader.Refusal.new(REFUSE_ARENA_NOT_REBUILDABLE,
			"the arena cursor is at %d, the record at %d"
				% [store.payload_used(), record.payload_used])
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _store_scheduler_refusal(record: Record,
		store: SchedulerEventsScript) -> SaveHeader.Refusal:
	"""Compare every queued event and the four control counters with the Record's."""
	var event: SchedulerEventsScript.Event = SchedulerEventsScript.Event.new()
	for position: int in record.scheduler_count:
		store.read_into(position, event)
		if event.sequence_high != record.event_sequence_high[position] \
				or event.sequence_low != record.event_sequence_low[position]:
			return SaveHeader.Refusal.new(REFUSE_SEQUENCE_ORDER,
				"scheduler position %d carries a different sequence than the record" % position)
		if event.kind != record.event_kind[position] \
				or event.reason != record.event_reason[position] \
				or event.value != record.event_value[position]:
			return SaveHeader.Refusal.new(REFUSE_STORE_REFUSED,
				"scheduler position %d disagrees with the record on kind, reason or value"
					% position)
	if store.last_drained_boundary() != record.scheduler_last_drained_boundary:
		return SaveHeader.Refusal.new(REFUSE_CONTROL,
			"the queue last drained at %d, the record at %d"
				% [store.last_drained_boundary(), record.scheduler_last_drained_boundary])
	return SaveHeader.Refusal.new(REFUSE_NONE, "")
