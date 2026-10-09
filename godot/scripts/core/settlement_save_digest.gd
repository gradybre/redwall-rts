extends RefCounted
## Section 15 STATE_DIGEST for the settlement save (ADR 1222 build step 7).
##
## `digest_of(staged, movement, inputs)` registers a canonical value adapter for EVERY owner of the
## production declaration over the staged, decoded-form records the file carries, then walks it.
## Because capture and load both hash the same records -- capture's staged ones, load's decoded
## ones -- a load that recomputes this digest and compares it with section 15 proves the file's
## state is exactly the state that was saved (ARCH-HASH-001). No subset digest exists: an owner
## without an adapter makes `digest_into()` refuse CANONICAL_NO_ADAPTER.
##
## Sections 1, 5, 6, 7 (inventory) and 13 register through their own modules. The adapters here
## cover section 2's movement profile revisions (read from the live movement store, since section 2
## carries no value for them and the capture refuses any revised profile), section 3, all eighteen
## section 4 owners, the other five section 7 owners, sections 8-12 and section 14.
##
## The section 15 body is the 32 raw digest bytes.
##
## NO FLOAT. ARCH-AUTH-002: there is no float in this file and there must never be one.

const Digest := preload("res://scripts/core/canonical_state_hash.gd")
const SaveIdentity := preload("res://scripts/core/save_identity_hashes.gd")
const Capture := preload("res://scripts/core/settlement_save_capture.gd")
const S01 := preload("res://scripts/core/save_section_01.gd")
const S03 := preload("res://scripts/core/save_section_directory.gd")
const S04 := preload("res://scripts/core/save_section_component_columns.gd")
const S04Schema := preload("res://scripts/core/save_component_columns_schema.gd")
const S05 := preload("res://scripts/core/save_section_child_arenas.gd")
const S06 := preload("res://scripts/core/save_section_auxiliary.gd")
const S07 := preload("res://scripts/core/save_section_inventories.gd")
const S08 := preload("res://scripts/core/save_section_job_indexes.gd")
const S09 := preload("res://scripts/core/save_section_navigation.gd")
const S10 := preload("res://scripts/core/save_section_rng.gd")
const S11 := preload("res://scripts/core/save_section_event_schedule.gd")
const S12 := preload("res://scripts/core/save_section_pending_commands.gd")
const S13 := preload("res://scripts/core/save_section_chronicle.gd")
const S14 := preload("res://scripts/core/save_section_name_pool.gd")
const MovementScript := preload("res://scripts/core/movement.gd")

const REFUSE_FIELD: StringName = &"SAVE_DIGEST_FIELD"


class DigestOutcome:
	"""The 32-byte digest, or a refusal and no digest."""
	var ok: bool = false
	var digest: PackedByteArray = PackedByteArray()
	var code: StringName = &""
	var detail: String = ""


static func _no_field(out: Digest.FieldValues, owner: String, key: StringName) -> bool:
	"""Refuse an undeclared field of one owner."""
	return out.refuse(REFUSE_FIELD, "'%s' supplies no field '%s'" % [owner, key])


# --- adapters -------------------------------------------------------------------------------------

class ProfileRevisionAdapter:
	"""Section 2 `movement._profile_revision`, from the live store (no section 2 value exists)."""
	var _revisions: PackedInt32Array = PackedInt32Array()

	func _init(p_movement: MovementScript) -> void:
		"""Copy the four published revisions."""
		_revisions = p_movement._profile_revision.duplicate()

	func canonical_field_values(key: StringName, out: Digest.FieldValues) -> bool:
		"""The four revisions."""
		if key != &"_profile_revision":
			return SaveDigest._no_field(out, "movement", key)
		return out.supply_int32(_revisions, _revisions.size())


class DirectoryAdapter:
	"""Section 3 `entity_directory`: the six columns at full capacity."""
	var _record: S03.Record = null

	func _init(p_record: S03.Record) -> void:
		"""Bind the staged record."""
		_record = p_record

	func canonical_field_values(key: StringName, out: Digest.FieldValues) -> bool:
		"""One of the six columns."""
		match key:
			&"_active": return out.supply_bytes(_record.active, _record.active.size())
			&"_retired": return out.supply_bytes(_record.retired, _record.retired.size())
			&"_generation": return out.supply_int32(_record.generation, _record.generation.size())
			&"_persistent_id":
				return out.supply_int32(_record.persistent_id, _record.persistent_id.size())
			&"_kind": return out.supply_int32(_record.kind, _record.kind.size())
			&"_typed_row": return out.supply_int32(_record.typed_row, _record.typed_row.size())
		return SaveDigest._no_field(out, "entity_directory", key)


class FramedAdapter:
	"""One section 4 owner over its FramedOwner record."""
	var _record: S04.FramedOwner = null

	func _init(p_record: S04.FramedOwner) -> void:
		"""Bind the staged record."""
		_record = p_record

	func canonical_field_values(key: StringName, out: Digest.FieldValues) -> bool:
		"""The column of the field whose compiled key is `key`, at its element count."""
		var owner: int = _record.owner
		for field: int in S04Schema.field_count(owner):
			if S04Schema.field_key(owner, field) != String(key):
				continue
			var type_code: int = S04Schema.field_type(owner, field)
			if type_code == S04Schema.TYPE_U8:
				var bytes: PackedByteArray = _record.u8_column(field)
				return out.supply_bytes(bytes, bytes.size())
			if type_code == S04Schema.TYPE_I32:
				var words: PackedInt32Array = _record.i32_column(field)
				return out.supply_int32(words, words.size())
			var longs: PackedInt64Array = _record.i64_column(field)
			return out.supply_int64(longs, longs.size())
		return SaveDigest._no_field(out, S04Schema.owner_key(owner), key)


class InventoryOwnerAdapter:
	"""One section 7 owner (other than inventory) over its OwnerRecord."""
	var _block: S07.OwnerRecord = null

	func _init(p_block: S07.OwnerRecord) -> void:
		"""Bind the staged block."""
		_block = p_block

	func canonical_field_values(key: StringName, out: Digest.FieldValues) -> bool:
		"""The column of `key` at its persisted count."""
		var ordinal: int = S07.field_keys_of(_block.owner).find(key)
		if ordinal < 0:
			return SaveDigest._no_field(out, S07.OWNER_KEYS[_block.owner], key)
		var count: int = S07.persisted_count_of(_block, ordinal)
		var type_code: int = S07.field_type_of(_block.owner, ordinal)
		if type_code == S07.TYPE_U8:
			return out.supply_bytes(_block.u8_column(ordinal), count)
		if type_code == S07.TYPE_I32:
			return out.supply_int32(_block.i32_column(ordinal), count)
		return out.supply_int64(_block.i64_column(ordinal), count)


class JobIndexAdapter:
	"""Section 8 `job_planner` over its Record."""
	var _record: S08.Record = null

	func _init(p_record: S08.Record) -> void:
		"""Bind the staged record."""
		_record = p_record

	func canonical_field_values(key: StringName, out: Digest.FieldValues) -> bool:
		"""The column of `key`, at its declared extent."""
		var field: int = S08.FIELD_KEYS.find(key)
		if field < 0:
			return SaveDigest._no_field(out, "job_planner", key)
		var index: int = S08.FIELD_STORAGE[field]
		var extent: int = S08.FIELD_EXTENTS[field]
		var width: int = S08.FIELD_WIDTHS[field]
		if width == 1:
			return out.supply_bytes(_record.u8_columns[index], extent)
		if width == 4:
			return out.supply_int32(_record.i32_columns[index], extent)
		return out.supply_int64(_record.i64_columns[index], extent)


class NavigationAdapter:
	"""Section 9 `movement` or `navigation` over the Record's wire fields."""
	var _record: S09.Record = null
	var _block: int = 0

	func _init(p_record: S09.Record, p_block: int) -> void:
		"""Bind the staged record and one of its two owner blocks."""
		_record = p_record
		_block = p_block

	func canonical_field_values(key: StringName, out: Digest.FieldValues) -> bool:
		"""The wire field of `key` in this block, decoded from its little-endian slice."""
		for wire: int in S09.wire_field_total():
			if S09.wire_block_of(wire) != _block or S09.wire_field_key(wire) != key:
				continue
			var count: int = S09.wire_field_count(_record, wire)
			var raw: PackedByteArray = S09.wire_field_slice(_record, wire, 0, count)
			if S09.wire_field_width(wire) == 1:
				return out.supply_bytes(raw, count)
			return out.supply_int32(raw.to_int32_array(), count)
		return SaveDigest._no_field(out, "navigation" if _block != 0 else "movement", key)


class RngAdapter:
	"""Section 10 `rng`: nine stream states (u32 bit patterns) and draw counts."""
	var _record: S10.Record = null

	func _init(p_record: S10.Record) -> void:
		"""Bind the staged record."""
		_record = p_record

	func canonical_field_values(key: StringName, out: Digest.FieldValues) -> bool:
		"""States or draw counts."""
		if key == &"_state":
			return out.supply_int32(_record.states, _record.states.size())
		if key == &"_draw_count":
			return out.supply_int64(_record.draw_counts, _record.draw_counts.size())
		return SaveDigest._no_field(out, "rng", key)


class EventScheduleAdapter:
	"""Section 11 `event_schedule` over its Record."""
	var _record: S11.Record = null

	func _init(p_record: S11.Record) -> void:
		"""Bind the staged record."""
		_record = p_record

	func canonical_field_values(key: StringName, out: Digest.FieldValues) -> bool:
		"""One scalar or one row column at the row count."""
		var rows: int = _record.row_count()
		match key:
			&"_next_sequence": return out.supply_int64(PackedInt64Array([_record.next_sequence]), 1)
			&"_count": return out.supply_int64(PackedInt64Array([rows]), 1)
			&"_kind": return out.supply_int32(_record.kind, rows)
			&"_source_id": return out.supply_int32(_record.source_id, rows)
			&"_arg0": return out.supply_int32(_record.arg0, rows)
			&"_arg1": return out.supply_int32(_record.arg1, rows)
			&"_due_tick": return out.supply_int64(_record.due_tick, rows)
			&"_sequence": return out.supply_int64(_record.sequence, rows)
		return SaveDigest._no_field(out, "event_schedule", key)


class CommandsAdapter:
	"""Section 12 `commands`: the economic queue window."""
	var _r: S12.Record = null

	func _init(p_record: S12.Record) -> void:
		"""Bind the staged record."""
		_r = p_record

	func canonical_field_values(key: StringName, out: Digest.FieldValues) -> bool:
		"""A scalar, a row column at the economic count, or the payload prefix."""
		var scalars: Dictionary = {&"_count": _r.economic_count, &"_payload_used": _r.payload_used,
			&"_next_sequence_high": _r.economic_next_sequence_high,
			&"_next_sequence_low": _r.economic_next_sequence_low}
		if scalars.has(key):
			return out.supply_int64(PackedInt64Array([int(scalars[key])]), 1)
		if key == &"_execute_tick":
			return out.supply_int64(_r.execute_tick, _r.economic_count)
		if key == &"_payload":
			return out.supply_bytes(_r.payload, _r.payload_used)
		var columns: Dictionary = {&"_player_id": _r.player_id, &"_sequence_low": _r.sequence_low,
			&"_sequence_high": _r.sequence_high, &"_kind": _r.kind, &"_target_slot": _r.target_slot,
			&"_target_generation": _r.target_generation, &"_goal_x": _r.goal_x,
			&"_goal_z": _r.goal_z, &"_arg0": _r.arg0, &"_arg1": _r.arg1,
			&"_payload_offset": _r.payload_offset, &"_payload_length": _r.payload_length,
			&"_flags": _r.flags, &"_reserved_zero": _r.reserved_zero}
		if columns.has(key):
			return out.supply_int32(columns[key], _r.economic_count)
		return SaveDigest._no_field(out, "commands", key)


class SchedulerAdapter:
	"""Section 12 `scheduler_events`: the scheduler queue window."""
	var _r: S12.Record = null

	func _init(p_record: S12.Record) -> void:
		"""Bind the staged record."""
		_r = p_record

	func canonical_field_values(key: StringName, out: Digest.FieldValues) -> bool:
		"""A scalar or a row column at the scheduler count."""
		var scalars: Dictionary = {&"_head": _r.scheduler_head, &"_count": _r.scheduler_count,
			&"_next_sequence_low": _r.scheduler_next_sequence_low,
			&"_next_sequence_high": _r.scheduler_next_sequence_high,
			&"_last_applied_sequence_low": _r.scheduler_last_applied_low,
			&"_last_applied_sequence_high": _r.scheduler_last_applied_high,
			&"_last_drained_boundary": _r.scheduler_last_drained_boundary}
		if scalars.has(key):
			return out.supply_int64(PackedInt64Array([int(scalars[key])]), 1)
		if key == &"_boundary_tick":
			return out.supply_int64(_r.boundary_tick, _r.scheduler_count)
		var columns: Dictionary = {&"_sequence_low": _r.event_sequence_low,
			&"_sequence_high": _r.event_sequence_high, &"_kind": _r.event_kind,
			&"_reason": _r.event_reason, &"_value": _r.event_value,
			&"_reserved": _r.event_reserved}
		if columns.has(key):
			return out.supply_int32(columns[key], _r.scheduler_count)
		return SaveDigest._no_field(out, "scheduler_events", key)


class NamePoolAdapter:
	"""Section 14 `residents._name_key`: one text per resident row."""
	var _record: S14.Record = null

	func _init(p_record: S14.Record) -> void:
		"""Bind the staged record."""
		_record = p_record

	func canonical_field_values(key: StringName, out: Digest.FieldValues) -> bool:
		"""The 512 name keys."""
		if key != &"_name_key":
			return SaveDigest._no_field(out, "residents", key)
		return out.supply_texts(_record.names, _record.names.size())


# --- the walk -------------------------------------------------------------------------------------

## Self-preload so the inner classes can reach `_no_field()`.
const SaveDigest := preload("res://scripts/core/settlement_save_digest.gd")


static func register_all(walker: Digest.Walker, staged: Capture.Staged,
		movement: MovementScript) -> Digest.Refusal:
	"""Every owner of the production declaration, over `staged` (and `movement` for section 2)."""
	var refusals: Array[Digest.Refusal] = [S01.register_adapters(walker, staged.s01),
		S05.register_adapters(walker, staged.s05), S06.register_adapters(walker, staged.s06),
		S07.register_inventory_adapter(walker, staged.s07),
		S13.register_adapter(walker, staged.s13),
		walker.register_owner(2, "movement", ProfileRevisionAdapter.new(movement)),
		walker.register_owner(3, "entity_directory", DirectoryAdapter.new(staged.s03))]
	for record: S04.FramedOwner in staged.s04:
		refusals.append(walker.register_owner(4, S04Schema.owner_key(record.owner),
			FramedAdapter.new(record)))
	for owner: int in S07.OWNER_COUNT:
		if owner != S07.OWNER_INVENTORY:
			refusals.append(walker.register_owner(7, S07.OWNER_KEYS[owner],
				InventoryOwnerAdapter.new(staged.s07.of(owner))))
	refusals.append_array(_register_tail(walker, staged))
	for refusal: Digest.Refusal in refusals:
		if not refusal.is_ok():
			return refusal
	return Digest.Refusal.new(Digest.REFUSE_NONE, "")


static func _register_tail(walker: Digest.Walker, staged: Capture.Staged) -> Array[Digest.Refusal]:
	"""Sections 8 to 12 and 14."""
	return [walker.register_owner(8, "job_planner", JobIndexAdapter.new(staged.s08)),
		walker.register_owner(9, "movement", NavigationAdapter.new(staged.s09, 0)),
		walker.register_owner(9, "navigation", NavigationAdapter.new(staged.s09, 1)),
		walker.register_owner(10, "rng", RngAdapter.new(staged.s10)),
		walker.register_owner(11, "event_schedule", EventScheduleAdapter.new(staged.s11)),
		walker.register_owner(12, "commands", CommandsAdapter.new(staged.s12)),
		walker.register_owner(12, "scheduler_events", SchedulerAdapter.new(staged.s12)),
		walker.register_owner(14, "residents", NamePoolAdapter.new(staged.s14))]


static func inputs_for(header_rules: PackedByteArray, header_catalog: PackedByteArray,
		header_map: PackedByteArray, header_lookup: PackedByteArray,
		completed_tick: int) -> Digest.Inputs:
	"""The walk's identity inputs: the file's four digests, this engine's line and the tick."""
	var inputs: Digest.Inputs = Digest.Inputs.new()
	inputs.rules_digest = header_rules
	inputs.catalog_digest = header_catalog
	inputs.map_digest = header_map
	inputs.lookup_digest = header_lookup
	inputs.engine_identity_line = SaveIdentity.engine_identity_line(
		Engine.get_version_info()).text
	inputs.completed_tick = completed_tick
	return inputs


static func digest_of(staged: Capture.Staged, movement: MovementScript,
		inputs: Digest.Inputs) -> DigestOutcome:
	"""Register every adapter and walk the production declaration."""
	var outcome: DigestOutcome = DigestOutcome.new()
	var walker: Digest.Walker = Digest.production_walker()
	var registered: Digest.Refusal = register_all(walker, staged, movement)
	if not registered.is_ok():
		outcome.code = registered.code
		outcome.detail = registered.detail
		return outcome
	var result: Digest.DigestResult = Digest.DigestResult.new()
	var walked: Digest.Refusal = walker.digest_into(inputs, result, 0)
	if not walked.is_ok():
		outcome.code = walked.code
		outcome.detail = walked.detail
		return outcome
	outcome.ok = true
	outcome.digest = result.digest
	return outcome
