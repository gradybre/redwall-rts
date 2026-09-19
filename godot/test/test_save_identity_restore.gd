extends "res://test/framework/test_case.gd"
## Adversarial suite for SAVE-D2-R02's joint directory/cursor restore boundary.
##
## These are IDENTITY-SECTION round trips, not full saves: there is no disk file, no header, no
## whole-world transaction and none is claimed. What is exercised is the real thing on both sides
## -- actual `EntityDirectory` objects, actual §3 bytes through `capture_into` -> `encode_record`
## -> `decode_into`, and the §1 cursor encoded and decoded separately as the `u32 LE` scalar
## REG-R01 assigns it.
##
## THE FAILURE THIS SUITE EXISTS TO CATCH IS SILENT. A loader that derives `max(live ids) + 1`
## produces a perfectly plausible world that reissues identities the save already spent: create
## 1/2/3, destroy 3, and the derivation yields 3 again; destroy everything and it yields 1. So the
## proof here is an ACTUAL ALLOCATION after the restore, observed through `get_persistent_id()`,
## rather than a comparison of the cursor against itself.
##
## MEMORY. Every directory allocates 352418-slot packed columns and `state_bytes()` is about ten
## megabytes, so no test holds more than two capacity-sized images at once, the source directory
## is dropped as soon as its bytes are decoded, and `after_each()` releases every fixture.

const SaveCodec := preload("res://scripts/core/save_codec.gd")
const SaveHeader := preload("res://scripts/core/save_header.gd")
const SaveSectionDirectory := preload("res://scripts/core/save_section_directory.gd")
const EntityDirectoryScript := preload("res://scripts/core/entity_directory.gd")
const SimClockScript := preload("res://scripts/core/sim_clock.gd")
const SaveIdentityRestore := preload("res://scripts/core/save_identity_restore.gd")

## One kind is enough for identity: the cursor is global and never per kind.
const KIND: int = EntityDirectoryScript.KIND_ROOM

var _clock: SimClockScript = null
var _barrier: SimClockScript.LoadBarrier = null
var _target: EntityDirectoryScript = null


func before_each() -> void:
	"""A fresh target directory and a clock whose load barrier this suite holds."""
	_clock = SimClockScript.new()
	var grant: SimClockScript.LoadBarrierGrant = _clock.acquire_load_barrier()
	assert_true(grant.is_ok(), "the barrier was granted: %s" % grant.detail)
	_barrier = grant.token
	_target = EntityDirectoryScript.new()


func after_each() -> void:
	"""Release every fixture reference so two tests never hold four capacity-sized column sets."""
	_barrier = null
	_clock = null
	_target = null


# --- helpers ---------------------------------------------------------------------------------------

func _hex(bytes: PackedByteArray) -> String:
	"""Lowercase hex of a byte run, for pinned vectors."""
	var text: String = ""
	for value: int in bytes:
		text += "%02x" % value
	return text


func _cursor_round_trip(cursor: int, pinned: String) -> int:
	"""Encode the §1 cursor as `u32 LE`, pin its bytes, and decode it back through SaveCodec."""
	var writer: SaveCodec.Writer = SaveCodec.Writer.new(SaveCodec.U32_BYTES)
	assert_true(writer.write_u32(cursor), "cursor %d encodes as u32: %s" % [cursor, writer.detail()])
	assert_equal(_hex(writer.to_bytes()), pinned, "cursor %d pins those four bytes" % cursor)
	var reader: SaveCodec.Reader = SaveCodec.Reader.new(writer.to_bytes())
	var scalar: SaveCodec.Scalar = SaveCodec.Scalar.new()
	assert_true(reader.read_u32_into(scalar), "and decodes back: %s" % reader.detail())
	assert_equal(scalar.value, cursor, "to the same cursor")
	return scalar.value


func _decoded(source: EntityDirectoryScript) -> SaveSectionDirectory.Record:
	"""capture -> encode -> decode: actual section 3 bytes, never a hand-built Record."""
	var captured: SaveSectionDirectory.Record = SaveSectionDirectory.Record.new()
	var capture: SaveHeader.Refusal = SaveSectionDirectory.capture_into(source, captured)
	assert_true(capture.is_ok(), "captured: %s %s" % [capture.code, capture.detail])
	var encoded: SaveSectionDirectory.EncodeResult = SaveSectionDirectory.EncodeResult.new()
	assert_true(SaveSectionDirectory.encode_record(captured, encoded),
		"encoded: %s %s" % [encoded.refusal, encoded.detail])
	var decoded: SaveSectionDirectory.Record = SaveSectionDirectory.Record.new()
	var decode: SaveHeader.Refusal = SaveSectionDirectory.decode_into(encoded.bytes, 0, decoded)
	assert_true(decode.is_ok(), "decoded: %s %s" % [decode.code, decode.detail])
	return decoded


func _three_identities(destroy_all: bool) -> SaveSectionDirectory.Record:
	"""Issue identities 1/2/3, destroy 3 (and optionally the rest), and return the decoded §3.

	Either way the saved cursor is 4, and either way a derivation would be wrong: `max(live) + 1`
	gives 3 with two rows alive and 1 with none.
	"""
	var source: EntityDirectoryScript = EntityDirectoryScript.new()
	var refs: Array[Vector2i] = []
	for index: int in 3:
		refs.append(source.create(KIND))
	assert_equal(source.get_persistent_id(refs[2]), 3, "the third identity issued is 3")
	assert_true(source.destroy(refs[2]), "identity 3 is spent and its row destroyed")
	if destroy_all:
		assert_true(source.destroy(refs[0]), "and identity 1's row too")
		assert_true(source.destroy(refs[1]), "and identity 2's, leaving nothing alive")
	assert_equal(source.next_persistent_id(), 4, "the saved cursor is 4")
	return _decoded(source)


func _refuse_cursor(record: SaveSectionDirectory.Record, cursor: int, code: StringName,
		before: PackedByteArray) -> void:
	"""Assert one cursor refuses with the owner's exact code and leaves the target byte-identical."""
	var refusal: SaveHeader.Refusal = SaveIdentityRestore.apply(record, cursor, _target, _clock)
	assert_equal(refusal.code, code, "cursor %d refuses with the owner's exact code" % cursor)
	assert_true(_target.state_bytes() == before,
		"and the target is byte-identical after cursor %d, its own cursor included" % cursor)


# --- the cursor is assigned, never derived -------------------------------------------------------------

func test_a_restored_cursor_issues_the_identity_after_the_destroyed_one() -> void:
	"""Create 1/2/3, destroy 3, restore with cursor 4: the next actual allocation must be 4."""
	var decoded: SaveSectionDirectory.Record = _three_identities(false)
	var saved_cursor: int = _cursor_round_trip(4, "04000000")
	var refusal: SaveHeader.Refusal = SaveIdentityRestore.apply(decoded, saved_cursor, _target, _clock)
	assert_true(refusal.is_ok(), "apply succeeds: %s %s" % [refusal.code, refusal.detail])
	assert_equal(_target.next_persistent_id(), 4, "the saved cursor was assigned")
	assert_equal(_target.total_live_count(), 2, "and the two surviving rows landed")
	var created: Vector2i = _target.create(KIND)
	assert_true(_target.is_valid(created), "the allocation succeeded")
	assert_equal(_target.get_persistent_id(created), 4,
		"the restored world issues 4; a derived cursor would have reissued the spent 3")


func test_a_world_with_every_row_destroyed_still_issues_four() -> void:
	"""With nothing alive, `max(live ids) + 1` collapses to 1. The saved cursor does not."""
	var decoded: SaveSectionDirectory.Record = _three_identities(true)
	var saved_cursor: int = _cursor_round_trip(4, "04000000")
	var refusal: SaveHeader.Refusal = SaveIdentityRestore.apply(decoded, saved_cursor, _target, _clock)
	assert_true(refusal.is_ok(), "apply succeeds: %s %s" % [refusal.code, refusal.detail])
	assert_equal(_target.total_live_count(), 0, "the restored world is empty")
	var created: Vector2i = _target.create(KIND)
	assert_true(_target.is_valid(created), "the allocation succeeded")
	assert_equal(_target.get_persistent_id(created), 4,
		"and it issues 4, not the 1 a derivation would have produced")


func test_the_final_identity_round_trips_and_exhaustion_is_retained() -> void:
	"""Stage the last signed-int32 cursor through the owner API, spend it, and reload EXHAUSTED.

	The cursor travels as its own `u32 LE` scalar, separately from §3's six columns, because that
	is where REG-R01 puts it -- and 2147483648 has no i32 spelling at all, which is exactly why
	the bytes `00 00 00 80` are pinned here.
	"""
	var source: EntityDirectoryScript = EntityDirectoryScript.new()
	var staged: SaveSectionDirectory.Record = SaveSectionDirectory.Record.new()
	assert_true(SaveSectionDirectory.capture_into(source, staged).is_ok(), "captured an empty world")
	assert_true(source.restore_columns_and_cursor(staged.active, staged.generation, staged.retired,
		staged.persistent_id, staged.kind, staged.typed_row, EntityDirectoryScript.MAX_INT32),
		"the existing owner API stages the final cursor: %s" % source.last_column_refusal())
	var last: Vector2i = source.create(KIND)
	assert_equal(source.get_persistent_id(last), EntityDirectoryScript.MAX_INT32,
		"the last signed-int32 identity is issued")
	assert_equal(source.next_persistent_id(), EntityDirectoryScript.PERSISTENT_ID_EXHAUSTED,
		"leaving the cursor EXHAUSTED")
	var cursor: int = _cursor_round_trip(source.next_persistent_id(), "00000080")
	var decoded: SaveSectionDirectory.Record = _decoded(source)
	source = null
	var refusal: SaveHeader.Refusal = SaveIdentityRestore.apply(decoded, cursor, _target, _clock)
	assert_true(refusal.is_ok(), "apply succeeds: %s %s" % [refusal.code, refusal.detail])
	assert_equal(_target.next_persistent_id(), EntityDirectoryScript.PERSISTENT_ID_EXHAUSTED,
		"exhaustion survives the round trip")
	assert_equal(_target.create(KIND), EntityDirectoryScript.NULL_REF,
		"and the next create refuses rather than reissuing")
	assert_equal(_target.last_refusal(), EntityDirectoryScript.REFUSAL_PERSISTENT_ID,
		"with the exhaustion code")


# --- refusals leave the target byte-identical -------------------------------------------------------------

func test_an_out_of_range_or_stale_cursor_refuses_with_the_owners_exact_code() -> void:
	"""0 and 2147483649 are out of range; a cursor that does not exceed a stored id is stale."""
	var decoded: SaveSectionDirectory.Record = _three_identities(false)
	var column: PackedInt32Array = decoded.persistent_id.duplicate()
	var before: PackedByteArray = _target.state_bytes()
	_refuse_cursor(decoded, 0, EntityDirectoryScript.REFUSAL_COLUMN_CURSOR_RANGE, before)
	_refuse_cursor(decoded, EntityDirectoryScript.PERSISTENT_ID_EXHAUSTED + 1,
		EntityDirectoryScript.REFUSAL_COLUMN_CURSOR_RANGE, before)
	_refuse_cursor(decoded, 2, EntityDirectoryScript.REFUSAL_COLUMN_CURSOR_STALE, before)
	assert_true(decoded.persistent_id == column, "the record's own column is unchanged throughout")
	assert_equal(_target.next_persistent_id(), EntityDirectoryScript.PERSISTENT_ID_MIN,
		"and the target still issues from 1, never repaired upward")


func test_a_malformed_column_set_refuses_before_the_owner_is_ever_asked() -> void:
	"""The record validator runs first, so an invalid §3 never reaches the directory at all."""
	var decoded: SaveSectionDirectory.Record = _three_identities(false)
	decoded.generation[0] = 0
	var before: PackedByteArray = _target.state_bytes()
	var refusal: SaveHeader.Refusal = SaveIdentityRestore.apply(decoded, 4, _target, _clock)
	assert_equal(refusal.code, SaveSectionDirectory.REFUSE_LIVE_SLOT_GENERATION,
		"a live slot at generation 0 is refused with the record's own code")
	assert_true(_target.state_bytes() == before, "nothing was published")
	assert_equal(_target.last_column_refusal(), EntityDirectoryScript.REFUSAL_NONE,
		"and the directory was never asked to restore anything")


func test_null_participants_refuse_explicitly() -> void:
	"""A missing record, store or clock is named, never dereferenced."""
	var decoded: SaveSectionDirectory.Record = _three_identities(false)
	assert_equal(SaveIdentityRestore.apply(null, 4, _target, _clock).code,
		SaveIdentityRestore.REFUSE_NULL_RECORD, "a null record refuses")
	assert_equal(SaveIdentityRestore.apply(decoded, 4, null, _clock).code,
		SaveIdentityRestore.REFUSE_NULL_STORE, "a null store refuses")
	assert_equal(SaveIdentityRestore.apply(decoded, 4, _target, null).code,
		SaveIdentityRestore.REFUSE_NULL_CLOCK, "a null clock refuses")
	assert_equal(_target.next_persistent_id(), EntityDirectoryScript.PERSISTENT_ID_MIN,
		"and the untouched target still issues from 1")
	assert_equal(_target.total_live_count(), 0, "with no row published")


func test_an_absent_or_released_barrier_refuses_and_pause_bits_are_not_the_barrier() -> void:
	"""RESTORE-R01 keeps the barrier out of the pause mask; PLAYER and LOAD do not stand in for it."""
	var decoded: SaveSectionDirectory.Record = _three_identities(false)
	var before: PackedByteArray = _target.state_bytes()
	var unbarred: SimClockScript = SimClockScript.new()
	assert_false(unbarred.is_load_barrier_held(), "a fresh clock holds no barrier")
	assert_true(unbarred.set_pause(SimClockScript.LOAD, true), "hold the LOAD pause bit")
	assert_true(unbarred.set_pause(SimClockScript.PLAYER, true), "and the PLAYER bit")
	assert_equal(SaveIdentityRestore.apply(decoded, 4, _target, unbarred).code,
		SaveIdentityRestore.REFUSE_BARRIER_NOT_HELD, "pause bits are not the load barrier")
	assert_true(_target.state_bytes() == before, "missing barrier preserves every directory byte")
	assert_true(_barrier.release(), "now lower this suite's own barrier")
	assert_equal(SaveIdentityRestore.apply(decoded, 4, _target, _clock).code,
		SaveIdentityRestore.REFUSE_BARRIER_NOT_HELD, "a released barrier refuses too")
	assert_true(_target.state_bytes() == before, "released barrier preserves every directory byte")
	assert_equal(_target.next_persistent_id(), EntityDirectoryScript.PERSISTENT_ID_MIN,
		"and nothing was published either time")
	assert_equal(_target.total_live_count(), 0, "no row landed")


# --- the clock is observed, never touched -------------------------------------------------------------------

func test_the_barrier_and_the_clock_survive_both_outcomes_unchanged() -> void:
	"""A held barrier stays held; tick, debt, pause mask and the discard counter never move."""
	var decoded: SaveSectionDirectory.Record = _three_identities(false)
	var tick: int = _clock.completed_tick()
	var debt: int = _clock.debt()
	var mask: int = _clock.pause_mask()
	var discards: int = _clock.subtick_debt_discards()
	assert_equal(SaveIdentityRestore.apply(decoded, 2, _target, _clock).code,
		EntityDirectoryScript.REFUSAL_COLUMN_CURSOR_STALE, "a refused apply")
	assert_true(_clock.is_load_barrier_held(), "leaves the barrier held")
	assert_true(SaveIdentityRestore.apply(decoded, 4, _target, _clock).is_ok(), "a successful apply")
	assert_true(_clock.is_load_barrier_held(), "leaves it held as well")
	assert_true(_barrier.is_held(), "and the token agrees it was never lowered")
	assert_equal(_clock.completed_tick(), tick, "the completed tick is unchanged")
	assert_equal(_clock.debt(), debt, "so is the scheduler debt")
	assert_equal(_clock.pause_mask(), mask, "and the pause mask")
	assert_equal(_clock.subtick_debt_discards(), discards, "no sub-tick discard was counted")


func test_the_target_never_aliases_the_decoded_records_arrays() -> void:
	"""Input columns are unchanged by a success, and a later mutation cannot reach the target."""
	var decoded: SaveSectionDirectory.Record = _three_identities(false)
	var column: PackedInt32Array = decoded.persistent_id.duplicate()
	assert_true(SaveIdentityRestore.apply(decoded, 4, _target, _clock).is_ok(), "apply succeeds")
	assert_true(decoded.persistent_id == column, "the input column survives the success unchanged")
	var restored: Vector2i = _target.ref_of_slot(0)
	assert_true(_target.is_valid(restored), "slot 0 came back live")
	assert_equal(_target.get_persistent_id(restored), 1, "carrying identity 1")
	decoded.active[0] = 0
	decoded.persistent_id[0] = 99
	decoded.generation[0] = 42
	assert_equal(_target.get_persistent_id(restored), 1,
		"mutating the decoded record afterwards cannot reach the target")
	assert_equal(_target.total_live_count(), 2, "and the live count is unmoved")
	assert_equal(_target.next_persistent_id(), 4, "as is the installed cursor")
