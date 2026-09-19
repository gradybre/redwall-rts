extends RefCounted
## SAVE-D2-R02: join ARCH-SAVE-002 §3's decoded ENTITY_DIRECTORY record to §1's decoded
## persistent-ID cursor, through the one existing owner call that installs both together.
##
## `save_section_01`'s capture already reads the cursor from `EntityDirectory.next_persistent_id()`,
## and `EntityDirectory.restore_columns_and_cursor()` already installs the six columns and that
## cursor as one indivisible step. The missing piece was a save-layer CONSUMER that hands the
## decoded §3 record and the decoded §1 cursor to that single owner call. That is all this module
## is: stateless, static, cold path. There is no seventh column in §3, no change to the frozen
## WORLD runtime body, and the full disk coordinator remains a separate thing entirely.
##
## THE COORDINATOR SUPPLIES THE CLOCK BOUND TO THIS DIRECTORY'S WORLD. Two independent objects
## carry no association this helper could infer, so that match is the caller's to own. What this
## module DOES enforce is that the clock's LOAD BARRIER is held before any mutation: ordinary
## PLAYER/LOAD pause bits are not that barrier, and `sim_clock.gd` keeps the barrier out of the
## pause mask deliberately ("The barrier is not a pause reason"). This module never acquires,
## releases or changes the barrier, and never touches a tick, debt, RNG, save or any other store.
##
## NEVER DERIVED, NEVER SPLIT. `clear()`, a bare `restore_columns()` and any `max(live ids) + 1`
## derivation are each wrong here, and none is called: `destroy()` zeroes `_persistent_id`, so a
## derived cursor reissues an identity the save already spent, and with every row dead it collapses
## to 1. The saved cursor is ASSIGNED. The owner validates its range and its comparison against
## every incoming stored identity before writing anything, and this module returns that owner's
## exact code rather than restating the rule.
##
## WHAT IS NOT CLAIMED. The owner method is atomic for these seven values and for nothing wider:
## no disk transaction and no whole-world rollback happen here. A lowered or missing barrier, a
## stale cursor or an invalid column set leaves `store.state_bytes()` byte-identical, the cursor
## included, because every rule is checked before the owner writes (decision 0059). The input
## record's arrays are unchanged on success and on refusal, and the target does not alias them --
## the owner takes private copies. An unsupported full-world restore remains unsupported.

const SaveSectionDirectory := preload("res://scripts/core/save_section_directory.gd")
const SaveHeader := preload("res://scripts/core/save_header.gd")
const EntityDirectoryScript := preload("res://scripts/core/entity_directory.gd")
const SimClockScript := preload("res://scripts/core/sim_clock.gd")

const REFUSE_NONE: StringName = SaveHeader.REFUSE_NONE
const REFUSE_NULL_RECORD: StringName = &"SAVE_IDENTITY_NULL_RECORD"
const REFUSE_NULL_STORE: StringName = &"SAVE_IDENTITY_NULL_STORE"
const REFUSE_NULL_CLOCK: StringName = &"SAVE_IDENTITY_NULL_CLOCK"
const REFUSE_BARRIER_NOT_HELD: StringName = &"SAVE_IDENTITY_BARRIER_NOT_HELD"


static func apply(record: SaveSectionDirectory.Record, next_persistent_id: int,
		store: EntityDirectoryScript, clock: SimClockScript) -> SaveHeader.Refusal:
	"""Install a decoded §3 record and a decoded §1 cursor into `store`, under `clock`'s barrier.

	The participants are checked first, then the record through `SaveSectionDirectory.
	record_refusal()`, and only then is the one owner call made with all six decoded columns and
	the actual decoded cursor. That owner validates the cursor's range and its comparison against
	every incoming stored identity before it writes a byte, so a refusal from either half leaves
	the directory byte-identical -- cursor included.

	Returns the EXACT record refusal, or the owner's EXACT `last_column_refusal()`, on failure;
	the existing empty refusal on success. `clock` must be the clock bound to THIS directory's
	world: the caller owns that association, and this helper cannot infer it.
	"""
	var participants: SaveHeader.Refusal = _participants_refusal(record, store, clock)
	if not participants.is_ok():
		return participants
	var invalid: SaveHeader.Refusal = SaveSectionDirectory.record_refusal(record)
	if not invalid.is_ok():
		return invalid
	if not store.restore_columns_and_cursor(record.active, record.generation, record.retired,
			record.persistent_id, record.kind, record.typed_row, next_persistent_id):
		return SaveHeader.Refusal.new(store.last_column_refusal(),
			("the directory refused the decoded columns or the cursor %d; neither the store nor "
				+ "the record was written") % next_persistent_id)
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _participants_refusal(record: SaveSectionDirectory.Record,
		store: EntityDirectoryScript, clock: SimClockScript) -> SaveHeader.Refusal:
	"""Refuse a missing participant, then a load barrier that is absent or already lowered.

	The barrier check is the last gate before validation and the first that can fail for a reason
	the request itself does not carry: the same record and cursor are legal a moment later, under
	a held barrier. A PLAYER or LOAD pause bit is NOT that barrier and does not satisfy this.
	"""
	if record == null:
		return SaveHeader.Refusal.new(REFUSE_NULL_RECORD, "no decoded section 3 record was supplied")
	if store == null:
		return SaveHeader.Refusal.new(REFUSE_NULL_STORE, "no entity directory was supplied")
	if clock == null:
		return SaveHeader.Refusal.new(REFUSE_NULL_CLOCK,
			"no clock was supplied, so no load barrier could be observed")
	if not clock.is_load_barrier_held():
		return SaveHeader.Refusal.new(REFUSE_BARRIER_NOT_HELD,
			"the supplied clock holds no load barrier; pause bits are not that barrier")
	return SaveHeader.Refusal.new(REFUSE_NONE, "")
