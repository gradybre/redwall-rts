# SAVE-J2-R02v2 owner half: exact top-level insertion fragment for job_planner.gd.
#
# Append verbatim to `godot/scripts/core/job_planner.gd`. It declares no `extends` and
# redefines nothing: every existing constant, column, counter and operation is untouched,
# and `JobIndexSchema`, `EntityDirectory`, `IntMath` and `SimClock` are already preloaded
# there. The parent integration owns the section 8 codec adapters, the load barrier, the
# shared-schema fixes, the registry rows, the tests and the docs.
#
# Category 3: `_last_column_refusal` is the ONLY field any failure on these paths writes.
# No owner array, derived counter, history column, operational diagnostic, collaborator
# store or scratch object changes on a refusal, and neither does the caller's record.

# --- SAVE-J2 owner column refusals ---------------------------------------------------------------

## The target or source record is null, or its typed groups/column extents are not the
## declared shape. Raised by the OUTPUT check of a capture and the INPUT check of a restore.
const REFUSE_COLUMN_SHAPE: StringName = &"COLUMN_JOB_INDEX_SHAPE"
## A domain, table or list rule refused: the shared validator's own verdict, a live dirty
## count outside the extent-1 i32 column it must narrow into, or a source whose membership
## bits or status-derived counters disagree with the columns they are derived from.
const REFUSE_COLUMN_RECORD: StringName = &"COLUMN_JOB_INDEX_RECORD"
## A reference that DOES resolve in the bound directory contradicts its expected kind or its
## owner typed row. A reference that does not resolve is legal and is preserved verbatim.
const REFUSE_COLUMN_REFERENCE: StringName = &"COLUMN_JOB_INDEX_REFERENCE"

## How many outcome diagnostics `_reset_counters()` assigns, and therefore how many trailing
## values `state_bytes()` emits. Reports that function rather than defining it; the assertion
## in `_assert_column_contracts()` is what keeps the two together.
const COLUMN_DIAGNOSTIC_COUNT: int = 21

# --- SAVE-J2 owner column diagnostic scalar -------------------------------------------------------

## The code from the most recent refused bulk column call, or REFUSE_NONE after a success.
## Category 3, not canonical, never persisted, and deliberately excluded from `state_bytes()`
## so a refusal cannot alter the image that proves it changed nothing.
var _last_column_refusal: StringName = REFUSE_NONE


func last_column_refusal() -> StringName:
	"""The code from the most recent refused column capture or restore; empty after a success.

	Deliberately SEPARATE from `last_blocker()`, which reports R06-JOB-008 capacity exhaustion
	and is read straight after a reconcile. The returned code identifies the STAGE that
	refused: shape, record (domain/table/list) or reference.
	"""
	return _last_column_refusal


func copy_job_index_columns_into(out: JobIndexSchema.Record) -> bool:
	"""Copy all 35 section 8 fields into a caller-owned record. False refuses; see
	`last_column_refusal()`.

	The order is fixed and every step precedes publication: the OUTPUT's shape, then the three
	live dirty counts in their NATIVE range before any narrowing into an extent-1 i32 column,
	then an exact staged duplicate of all 35 fields, then the source's own membership and
	derived-counter invariants, then the shared record validation, then the resolving-reference
	rules. Only after all of them does `out` change, and then every buffer is replaced with an
	independent copy: nothing the caller holds afterwards aliases an owner array, and mutating
	the result cannot reach this store.

	No normalization, no stale-row dropping, no sorting and no repair. Free rows, retained
	history and stale references are copied exactly as they stand.
	"""
	_assert_column_contracts()
	if not JobIndexSchema.shape_refusal(out).is_ok():
		return _refuse_columns(REFUSE_COLUMN_SHAPE)
	if not _live_dirty_counts_are_in_range():
		return _refuse_columns(REFUSE_COLUMN_RECORD)
	var staged: JobIndexSchema.Record = JobIndexSchema.Record.new()
	_stage_service_columns(staged)
	_stage_cycle_columns(staged)
	_stage_demand_columns(staged)
	_stage_hive_columns(staged)
	_stage_dirty_columns(staged)
	if not _source_invariants_hold():
		return _refuse_columns(REFUSE_COLUMN_RECORD)
	if not JobIndexSchema.record_refusal(staged).is_ok():
		return _refuse_columns(REFUSE_COLUMN_RECORD)
	if not _record_references_are_legal(staged):
		return _refuse_columns(REFUSE_COLUMN_REFERENCE)
	out.copy_from(staged)
	_last_column_refusal = REFUSE_NONE
	return true


func restore_job_index_columns(columns: JobIndexSchema.Record) -> bool:
	"""Install all 35 section 8 fields from a caller-owned record. False refuses; see
	`last_column_refusal()`.

	The WHOLE input is validated before the first owner write: shape, then the shared record
	rules, then the resolving-reference rules. A refusal therefore leaves every owner array,
	counter, diagnostic and scratch member byte-identical, and leaves the input record
	untouched (decision 0059's allocate-before-consume, applied to a load).

	On success the arrays are installed as INDEPENDENT copies, the three persisted dirty
	counts are assigned exactly, `_is_dirty`/`_is_zone_dirty`/`_is_hive_dirty` are rebuilt by
	zeroing and marking the saved prefix entries, the eight status/enablement counters are
	derived, and only then are the 21 outcome diagnostics reset for the new observation
	session. No `mark_all_*`, no `mark_*` operation, no `clear()`, no
	`revalidate_after_load()`, no reconcile, service, claim or collaborator mutation, and no
	signal. No job, ID, claim, good or unit of work is created or consumed.
	"""
	_assert_column_contracts()
	if not JobIndexSchema.shape_refusal(columns).is_ok():
		return _refuse_columns(REFUSE_COLUMN_SHAPE)
	if not JobIndexSchema.record_refusal(columns).is_ok():
		return _refuse_columns(REFUSE_COLUMN_RECORD)
	if not _record_references_are_legal(columns):
		return _refuse_columns(REFUSE_COLUMN_REFERENCE)
	_install_service_columns(columns)
	_install_cycle_columns(columns)
	_install_demand_columns(columns)
	_install_hive_columns(columns)
	_install_dirty_columns(columns)
	_rebuild_membership_bits()
	_derive_column_counters()
	_reset_counters()
	_last_column_refusal = REFUSE_NONE
	return true


func _refuse_columns(code: StringName) -> bool:
	"""Record one column refusal and answer false. The ONLY write any failure path performs."""
	_last_column_refusal = code
	return false


func _assert_column_contracts() -> void:
	"""Prove the shared domain counts still name their own final ordinal plus one.

	Every assertion here reads MODULE CONSTANTS only: a malformed record is refused, never
	asserted on. The parent integration may call this once from the constructor instead; both
	public entry points call it so the answer cannot go unchecked in the meantime.
	"""
	assert(STATUS_COUNT == STATUS_REQUESTED + 1, "the status domain must end at its last member")
	assert(REASON_COUNT == REASON_SOIL_INCOMPATIBLE + 1,
		"the gate reason domain must end at its last ordinal")
	assert(BLOCKER_COUNT == BLOCKER_SOURCE_REFUSED + 1,
		"the demand blocker domain must end at its last ordinal")
	assert(HIVE_BLOCKER_COUNT == HIVE_BLOCKER_ALREADY_SERVICED + 1,
		"the hive blocker domain must end at its last ordinal")
	assert(JobIndexSchema.FIELD_COUNT == 35, "section 8 declares exactly 35 fields")
	assert(JobIndexSchema.FIELD_DIRTY_HIVE_COUNT == JobIndexSchema.FIELD_COUNT - 1,
		"the last declared ordinal must be the hive dirty count")
	assert(COLUMN_DIAGNOSTIC_COUNT == 21,
		"state_bytes must emit every diagnostic _reset_counters assigns")
	assert(PackedInt32Array([JobIndexSchema.BYTE_ORDER_PROBE]).to_byte_array()
		== PackedByteArray([4, 3, 2, 1]), "the diagnostic image is little-endian")


# --- capture: native count range, staging, source invariants ---------------------------------------

func _live_dirty_counts_are_in_range() -> bool:
	"""True when all three live dirty counts fit their extent-1 i32 column without narrowing.

	The counts are read in their NATIVE 64-bit range first, so an injected value of 2^31 or a
	negative one is refused as the out-of-range count it is rather than silently truncated into
	a plausible column value.
	"""
	if _dirty_count < 0 or _dirty_count > OWNER_CAPACITY:
		return false
	if _dirty_zone_count < 0 or _dirty_zone_count > ZONE_OWNER_CAPACITY:
		return false
	if _dirty_hive_count < 0 or _dirty_hive_count > HIVE_OWNER_CAPACITY:
		return false
	return true


func _stage_service_columns(record: JobIndexSchema.Record) -> void:
	"""Stage the eleven pending-service columns, ordinals 0 to 10, as exact duplicates."""
	_stage_i32(record, JobIndexSchema.FIELD_OWNER_SLOT, _owner_slot)
	_stage_i32(record, JobIndexSchema.FIELD_OWNER_GENERATION, _owner_generation)
	_stage_i32(record, JobIndexSchema.FIELD_SERVICE_DAY, _service_day)
	_stage_i32(record, JobIndexSchema.FIELD_JOB_SLOT, _job_slot)
	_stage_i32(record, JobIndexSchema.FIELD_JOB_GENERATION, _job_generation)
	_stage_i32(record, JobIndexSchema.FIELD_SERVICED_DAY, _serviced_day)
	_stage_u8(record, JobIndexSchema.FIELD_STATUS, _status)
	_stage_u8(record, JobIndexSchema.FIELD_REQUIRES_WATER, _requires_water)
	_stage_i32(record, JobIndexSchema.FIELD_FIELD_CYCLE, _field_cycle)
	_stage_i32(record, JobIndexSchema.FIELD_REQUESTED_CROP, _requested_crop)
	_stage_u8(record, JobIndexSchema.FIELD_GATE_REASON, _gate_reason)


func _stage_cycle_columns(record: JobIndexSchema.Record) -> void:
	"""Stage the two per-plot field cycle columns, ordinals 11 and 12."""
	_stage_i32(record, JobIndexSchema.FIELD_CYCLE_CURSOR, _cycle_cursor)
	_stage_i32(record, JobIndexSchema.FIELD_COMPLETED_CYCLE, _completed_cycle)


func _stage_demand_columns(record: JobIndexSchema.Record) -> void:
	"""Stage the eight forage demand columns, ordinals 13 to 20."""
	_stage_u8(record, JobIndexSchema.FIELD_DEMAND_ENABLED, _demand_enabled)
	_stage_i32(record, JobIndexSchema.FIELD_DEMAND_OWNER_SLOT, _demand_owner_slot)
	_stage_i32(record, JobIndexSchema.FIELD_DEMAND_OWNER_GENERATION, _demand_owner_generation)
	_stage_u8(record, JobIndexSchema.FIELD_DEMAND_STATUS, _demand_status)
	_stage_u8(record, JobIndexSchema.FIELD_DEMAND_BLOCKER, _demand_blocker)
	_stage_i32(record, JobIndexSchema.FIELD_DEMAND_JOB_SLOT, _demand_job_slot)
	_stage_i32(record, JobIndexSchema.FIELD_DEMAND_JOB_GENERATION, _demand_job_generation)
	_stage_i64(record, JobIndexSchema.FIELD_DEMAND_QUANTIFIED_MILLI, _demand_quantified_milli)


func _stage_hive_columns(record: JobIndexSchema.Record) -> void:
	"""Stage the eight hive service columns, ordinals 21 to 28."""
	_stage_i32(record, JobIndexSchema.FIELD_HIVE_OWNER_SLOT, _hive_owner_slot)
	_stage_i32(record, JobIndexSchema.FIELD_HIVE_OWNER_GENERATION, _hive_owner_generation)
	_stage_i32(record, JobIndexSchema.FIELD_HIVE_SERVICE_DAY, _hive_service_day)
	_stage_i32(record, JobIndexSchema.FIELD_HIVE_JOB_SLOT, _hive_job_slot)
	_stage_i32(record, JobIndexSchema.FIELD_HIVE_JOB_GENERATION, _hive_job_generation)
	_stage_i64(record, JobIndexSchema.FIELD_HIVE_FEED_DEMAND_MILLI, _hive_feed_demand_milli)
	_stage_u8(record, JobIndexSchema.FIELD_HIVE_STATUS, _hive_status)
	_stage_u8(record, JobIndexSchema.FIELD_HIVE_BLOCKER, _hive_blocker)


func _stage_dirty_columns(record: JobIndexSchema.Record) -> void:
	"""Stage the three dirty row lists and their three exact counts, ordinals 29 to 34.

	The lists are copied in their EXACT stack order, tail included, because the order decides
	which owner the next drain reconciles first and therefore which job IDs the restored world
	goes on to issue. The counts are written only after `_live_dirty_counts_are_in_range()`.
	"""
	_stage_i32(record, JobIndexSchema.FIELD_DIRTY_ROWS, _dirty_rows)
	record.set_value(JobIndexSchema.FIELD_DIRTY_COUNT, 0, _dirty_count)
	_stage_i32(record, JobIndexSchema.FIELD_DIRTY_ZONE_ROWS, _dirty_zone_rows)
	record.set_value(JobIndexSchema.FIELD_DIRTY_ZONE_COUNT, 0, _dirty_zone_count)
	_stage_i32(record, JobIndexSchema.FIELD_DIRTY_HIVE_ROWS, _dirty_hive_rows)
	record.set_value(JobIndexSchema.FIELD_DIRTY_HIVE_COUNT, 0, _dirty_hive_count)


func _stage_u8(record: JobIndexSchema.Record, field: int, column: PackedByteArray) -> void:
	"""Install one u8 column into the staging record as an independent duplicate."""
	record.u8_columns[JobIndexSchema.FIELD_STORAGE[field]] = column.duplicate()


func _stage_i32(record: JobIndexSchema.Record, field: int, column: PackedInt32Array) -> void:
	"""Install one i32 column into the staging record as an independent duplicate."""
	record.i32_columns[JobIndexSchema.FIELD_STORAGE[field]] = column.duplicate()


func _stage_i64(record: JobIndexSchema.Record, field: int, column: PackedInt64Array) -> void:
	"""Install one i64 column into the staging record as an independent duplicate."""
	record.i64_columns[JobIndexSchema.FIELD_STORAGE[field]] = column.duplicate()


func _source_invariants_hold() -> bool:
	"""True when this store's own membership bits and derived counters agree with its columns.

	A capture publishes the dirty ORDER and the status columns; the bits and the eight counters
	are rebuilt from them on restore. If they disagree here, the bytes about to be published
	would restore into a different world than the one being captured, so the capture refuses
	rather than exporting a self-inconsistent image.
	"""
	if not _membership_agrees(_is_dirty, _dirty_rows, _dirty_count):
		return false
	if not _membership_agrees(_is_zone_dirty, _dirty_zone_rows, _dirty_zone_count):
		return false
	if not _membership_agrees(_is_hive_dirty, _dirty_hive_rows, _dirty_hive_count):
		return false
	return _derived_counters_agree()


func _membership_agrees(bits: PackedByteArray, rows: PackedInt32Array, count: int) -> bool:
	"""True when every byte is 0 or 1, exactly `count` are 1, and each saved prefix entry is 1.

	All three clauses are needed: the byte domain alone permits a 2, the count alone permits a
	balanced swap between two rows, and the prefix walk alone permits a marked row that no
	prefix entry names.
	"""
	if bits.count(0) + bits.count(1) != bits.size():
		return false
	if bits.count(1) != count:
		return false
	for index: int in count:
		var row: int = rows[index]
		if row < 0 or row >= bits.size():
			return false
		if bits[row] != 1:
			return false
	return true


func _derived_counters_agree() -> bool:
	"""True when each of the eight derived counters equals its own status or enablement count."""
	if _pending_count != _status.count(STATUS_PENDING):
		return false
	if _unmet_count != _status.count(STATUS_UNMET):
		return false
	if _requested_count != _status.count(STATUS_REQUESTED):
		return false
	if _demand_enabled_count != _demand_enabled.count(1):
		return false
	if _demand_pending_count != _demand_status.count(STATUS_PENDING):
		return false
	if _demand_unmet_count != _demand_status.count(STATUS_UNMET):
		return false
	if _hive_pending_count != _hive_status.count(STATUS_PENDING):
		return false
	if _hive_unmet_count != _hive_status.count(STATUS_UNMET):
		return false
	return true


# --- the resolving-reference rules -----------------------------------------------------------------

func _record_references_are_legal(record: JobIndexSchema.Record) -> bool:
	"""True when every reference that RESOLVES carries its expected kind and owner typed row.

	Stale references are legal and are preserved: a pending row may legitimately name a Job
	destroyed out of band, and the next normal reconcile creates a new generation exactly once.
	Nothing here queries an operational gate, requires a service to be executable, repairs a row
	early, or certifies another owner's forage claims or Job requester/target semantics.
	"""
	if not _service_references_are_legal(record):
		return false
	if not _demand_references_are_legal(record):
		return false
	return _hive_references_are_legal(record)


func _service_references_are_legal(record: JobIndexSchema.Record) -> bool:
	"""The service table: a resolving owner is the FarmPlot of its own row, a job is a Job."""
	var owner_slot: PackedInt32Array = record.i32_column(JobIndexSchema.FIELD_OWNER_SLOT)
	var owner_generation: PackedInt32Array = record.i32_column(
		JobIndexSchema.FIELD_OWNER_GENERATION)
	var job_slot: PackedInt32Array = record.i32_column(JobIndexSchema.FIELD_JOB_SLOT)
	var job_generation: PackedInt32Array = record.i32_column(JobIndexSchema.FIELD_JOB_GENERATION)
	for row: int in SERVICE_ROW_COUNT:
		if not _reference_is_legal(owner_slot[row], owner_generation[row],
				EntityDirectory.KIND_FARM_PLOT, row / OPERATION_COUNT):
			return false
		if not _reference_is_legal(job_slot[row], job_generation[row],
				EntityDirectory.KIND_JOB, -1):
			return false
	return true


func _demand_references_are_legal(record: JobIndexSchema.Record) -> bool:
	"""The demand tables: a resolving designation owns its zone row, a job is a Job.

	A retained reference on a DISABLED designation is checked by the same rule and refused by
	none of it: disablement is not deletion, and the reference it kept is still its own.
	"""
	var owner_slot: PackedInt32Array = record.i32_column(JobIndexSchema.FIELD_DEMAND_OWNER_SLOT)
	var owner_generation: PackedInt32Array = record.i32_column(
		JobIndexSchema.FIELD_DEMAND_OWNER_GENERATION)
	for zone_slot: int in ZONE_OWNER_CAPACITY:
		if not _reference_is_legal(owner_slot[zone_slot], owner_generation[zone_slot],
				EntityDirectory.KIND_HARVEST_ZONE, zone_slot):
			return false
	var job_slot: PackedInt32Array = record.i32_column(JobIndexSchema.FIELD_DEMAND_JOB_SLOT)
	var job_generation: PackedInt32Array = record.i32_column(
		JobIndexSchema.FIELD_DEMAND_JOB_GENERATION)
	for row: int in DEMAND_ROW_COUNT:
		if not _reference_is_legal(job_slot[row], job_generation[row],
				EntityDirectory.KIND_JOB, -1):
			return false
	return true


func _hive_references_are_legal(record: JobIndexSchema.Record) -> bool:
	"""The hive slice: a resolving owner is the Hive of its own row, a job is a Job."""
	var owner_slot: PackedInt32Array = record.i32_column(JobIndexSchema.FIELD_HIVE_OWNER_SLOT)
	var owner_generation: PackedInt32Array = record.i32_column(
		JobIndexSchema.FIELD_HIVE_OWNER_GENERATION)
	var job_slot: PackedInt32Array = record.i32_column(JobIndexSchema.FIELD_HIVE_JOB_SLOT)
	var job_generation: PackedInt32Array = record.i32_column(
		JobIndexSchema.FIELD_HIVE_JOB_GENERATION)
	for hive_slot: int in HIVE_OWNER_CAPACITY:
		if not _reference_is_legal(owner_slot[hive_slot], owner_generation[hive_slot],
				EntityDirectory.KIND_HIVE, hive_slot):
			return false
		if not _reference_is_legal(job_slot[hive_slot], job_generation[hive_slot],
				EntityDirectory.KIND_JOB, -1):
			return false
	return true


func _reference_is_legal(slot: int, generation: int, expected_kind: int,
		expected_row: int) -> bool:
	"""True for a null reference, for one that does not resolve, or for a correctly bound one.

	The null and stale answers are deliberately the same: `Directory.is_valid()` returning false
	is NOT grounds for refusal, because the actual stale_job_probe reproduces a pending row that
	legitimately names a destroyed Job. Only a reference that DOES resolve is held to its
	expected kind and, where the table names one, to its owner typed row. `expected_row` of -1
	means the row is not constrained, which is the case for every Job reference.
	"""
	if slot == EntityDirectory.NULL_SLOT:
		return true
	var ref: Vector2i = Vector2i(slot, generation)
	if not _directory.is_valid(ref):
		return true
	if not _directory.is_valid_of_kind(ref, expected_kind):
		return false
	if expected_row >= 0 and _directory.get_typed_row(ref) != expected_row:
		return false
	return true


# --- restore: installation, membership rebuild, derived counters -----------------------------------

func _install_service_columns(columns: JobIndexSchema.Record) -> void:
	"""Install the eleven pending-service columns as independent duplicates."""
	_owner_slot = columns.i32_column(JobIndexSchema.FIELD_OWNER_SLOT).duplicate()
	_owner_generation = columns.i32_column(JobIndexSchema.FIELD_OWNER_GENERATION).duplicate()
	_service_day = columns.i32_column(JobIndexSchema.FIELD_SERVICE_DAY).duplicate()
	_job_slot = columns.i32_column(JobIndexSchema.FIELD_JOB_SLOT).duplicate()
	_job_generation = columns.i32_column(JobIndexSchema.FIELD_JOB_GENERATION).duplicate()
	_serviced_day = columns.i32_column(JobIndexSchema.FIELD_SERVICED_DAY).duplicate()
	_status = columns.u8_column(JobIndexSchema.FIELD_STATUS).duplicate()
	_requires_water = columns.u8_column(JobIndexSchema.FIELD_REQUIRES_WATER).duplicate()
	_field_cycle = columns.i32_column(JobIndexSchema.FIELD_FIELD_CYCLE).duplicate()
	_requested_crop = columns.i32_column(JobIndexSchema.FIELD_REQUESTED_CROP).duplicate()
	_gate_reason = columns.u8_column(JobIndexSchema.FIELD_GATE_REASON).duplicate()


func _install_cycle_columns(columns: JobIndexSchema.Record) -> void:
	"""Install the two per-plot field cycle columns, which are durable allocation history."""
	_cycle_cursor = columns.i32_column(JobIndexSchema.FIELD_CYCLE_CURSOR).duplicate()
	_completed_cycle = columns.i32_column(JobIndexSchema.FIELD_COMPLETED_CYCLE).duplicate()


func _install_demand_columns(columns: JobIndexSchema.Record) -> void:
	"""Install the eight forage demand columns as independent duplicates."""
	_demand_enabled = columns.u8_column(JobIndexSchema.FIELD_DEMAND_ENABLED).duplicate()
	_demand_owner_slot = columns.i32_column(JobIndexSchema.FIELD_DEMAND_OWNER_SLOT).duplicate()
	_demand_owner_generation = columns.i32_column(
		JobIndexSchema.FIELD_DEMAND_OWNER_GENERATION).duplicate()
	_demand_status = columns.u8_column(JobIndexSchema.FIELD_DEMAND_STATUS).duplicate()
	_demand_blocker = columns.u8_column(JobIndexSchema.FIELD_DEMAND_BLOCKER).duplicate()
	_demand_job_slot = columns.i32_column(JobIndexSchema.FIELD_DEMAND_JOB_SLOT).duplicate()
	_demand_job_generation = columns.i32_column(
		JobIndexSchema.FIELD_DEMAND_JOB_GENERATION).duplicate()
	_demand_quantified_milli = columns.i64_column(
		JobIndexSchema.FIELD_DEMAND_QUANTIFIED_MILLI).duplicate()


func _install_hive_columns(columns: JobIndexSchema.Record) -> void:
	"""Install the eight hive service columns as independent duplicates."""
	_hive_owner_slot = columns.i32_column(JobIndexSchema.FIELD_HIVE_OWNER_SLOT).duplicate()
	_hive_owner_generation = columns.i32_column(
		JobIndexSchema.FIELD_HIVE_OWNER_GENERATION).duplicate()
	_hive_service_day = columns.i32_column(JobIndexSchema.FIELD_HIVE_SERVICE_DAY).duplicate()
	_hive_job_slot = columns.i32_column(JobIndexSchema.FIELD_HIVE_JOB_SLOT).duplicate()
	_hive_job_generation = columns.i32_column(
		JobIndexSchema.FIELD_HIVE_JOB_GENERATION).duplicate()
	_hive_feed_demand_milli = columns.i64_column(
		JobIndexSchema.FIELD_HIVE_FEED_DEMAND_MILLI).duplicate()
	_hive_status = columns.u8_column(JobIndexSchema.FIELD_HIVE_STATUS).duplicate()
	_hive_blocker = columns.u8_column(JobIndexSchema.FIELD_HIVE_BLOCKER).duplicate()


func _install_dirty_columns(columns: JobIndexSchema.Record) -> void:
	"""Install the three dirty row lists and assign their three exact persisted counts.

	The saved ORDER is preserved exactly: dirty order [0, 1] and [1, 0] are different worlds,
	because the drain pops the most recently marked owner first and the jobs that follow take
	their IDs in that order. An empty saved membership installs as empty and is never widened.
	"""
	_dirty_rows = columns.i32_column(JobIndexSchema.FIELD_DIRTY_ROWS).duplicate()
	_dirty_count = columns.value_of(JobIndexSchema.FIELD_DIRTY_COUNT, 0)
	_dirty_zone_rows = columns.i32_column(JobIndexSchema.FIELD_DIRTY_ZONE_ROWS).duplicate()
	_dirty_zone_count = columns.value_of(JobIndexSchema.FIELD_DIRTY_ZONE_COUNT, 0)
	_dirty_hive_rows = columns.i32_column(JobIndexSchema.FIELD_DIRTY_HIVE_ROWS).duplicate()
	_dirty_hive_count = columns.value_of(JobIndexSchema.FIELD_DIRTY_HIVE_COUNT, 0)


func _rebuild_membership_bits() -> void:
	"""Rebuild the three membership bitsets: zero, then mark the saved prefix entries only.

	No `mark_all_owners_dirty()`, `mark_all_zones_dirty()` or `mark_all_hives_dirty()` is
	called, and neither is any `mark_*` operation: those are event entry points that would
	invent demand the save never recorded, and an empty saved membership must stay empty.
	"""
	_is_dirty.fill(0)
	for index: int in _dirty_count:
		_is_dirty[_dirty_rows[index]] = 1
	_is_zone_dirty.fill(0)
	for index: int in _dirty_zone_count:
		_is_zone_dirty[_dirty_zone_rows[index]] = 1
	_is_hive_dirty.fill(0)
	for index: int in _dirty_hive_count:
		_is_hive_dirty[_dirty_hive_rows[index]] = 1


func _derive_column_counters() -> void:
	"""Derive the eight status and enablement counters from the installed columns.

	Category 2, not outcome diagnostics: some of them guard midnight settlement, so they are
	rebuilt exactly rather than reset. The order is the contract's own -- pending, unmet,
	requested; demand enabled, pending, unmet; hive pending, unmet.
	"""
	_pending_count = _status.count(STATUS_PENDING)
	_unmet_count = _status.count(STATUS_UNMET)
	_requested_count = _status.count(STATUS_REQUESTED)
	_demand_enabled_count = _demand_enabled.count(1)
	_demand_pending_count = _demand_status.count(STATUS_PENDING)
	_demand_unmet_count = _demand_status.count(STATUS_UNMET)
	_hive_pending_count = _hive_status.count(STATUS_PENDING)
	_hive_unmet_count = _hive_status.count(STATUS_UNMET)


# --- the diagnostic image --------------------------------------------------------------------------

func state_bytes() -> PackedByteArray:
	"""Diagnostic image of every member a column capture or restore can reach. COLD, not a tick.

	NOT the canonical wire image and not a substitute for one: for a successful round trip it is
	the RECORD bytes that are compared, because the diagnostics here intentionally begin a new
	observation session. This exists so a refused call can be proved to have changed nothing.

	Format v2, exactly: the 35 fields in ordinal order, each packed array as u32 length then its
	raw little-endian bytes and each canonical scalar count as SIGNED i64 so an injected
	out-of-range native count is preserved rather than truncated; then the three membership
	arrays in farm, zone, hive order, each as u32 length then bytes; then the eight derived
	counters as i64 in the order `_derive_column_counters()` writes them; then the 21
	diagnostics in exact `_reset_counters()` assignment order, each int as i64 and `_last_blocker`
	as a u32 UTF-8 byte length followed by its UTF-8 bytes.

	Excluded: `_last_column_refusal`, the borrowed collaborator stores, and the `_math` and
	`_calendar` scratch objects, which tests inspect separately. It never normalizes or mutates.
	"""
	var image: PackedByteArray = PackedByteArray()
	_append_service_bytes(image)
	_append_cycle_bytes(image)
	_append_demand_bytes(image)
	_append_hive_bytes(image)
	_append_dirty_bytes(image)
	_append_membership_bytes(image)
	_append_derived_bytes(image)
	_append_diagnostic_bytes(image)
	return image


func _append_service_bytes(image: PackedByteArray) -> void:
	"""Ordinals 0 to 10: the pending-service columns, in declared order."""
	_append_i32_column(image, _owner_slot)
	_append_i32_column(image, _owner_generation)
	_append_i32_column(image, _service_day)
	_append_i32_column(image, _job_slot)
	_append_i32_column(image, _job_generation)
	_append_i32_column(image, _serviced_day)
	_append_u8_column(image, _status)
	_append_u8_column(image, _requires_water)
	_append_i32_column(image, _field_cycle)
	_append_i32_column(image, _requested_crop)
	_append_u8_column(image, _gate_reason)


func _append_cycle_bytes(image: PackedByteArray) -> void:
	"""Ordinals 11 and 12: the per-plot field cycle history."""
	_append_i32_column(image, _cycle_cursor)
	_append_i32_column(image, _completed_cycle)


func _append_demand_bytes(image: PackedByteArray) -> void:
	"""Ordinals 13 to 20: the forage enablement and demand columns."""
	_append_u8_column(image, _demand_enabled)
	_append_i32_column(image, _demand_owner_slot)
	_append_i32_column(image, _demand_owner_generation)
	_append_u8_column(image, _demand_status)
	_append_u8_column(image, _demand_blocker)
	_append_i32_column(image, _demand_job_slot)
	_append_i32_column(image, _demand_job_generation)
	_append_i64_column(image, _demand_quantified_milli)


func _append_hive_bytes(image: PackedByteArray) -> void:
	"""Ordinals 21 to 28: the hive service columns."""
	_append_i32_column(image, _hive_owner_slot)
	_append_i32_column(image, _hive_owner_generation)
	_append_i32_column(image, _hive_service_day)
	_append_i32_column(image, _hive_job_slot)
	_append_i32_column(image, _hive_job_generation)
	_append_i64_column(image, _hive_feed_demand_milli)
	_append_u8_column(image, _hive_status)
	_append_u8_column(image, _hive_blocker)


func _append_dirty_bytes(image: PackedByteArray) -> void:
	"""Ordinals 29 to 34: the three dirty lists, each followed by its count as SIGNED i64.

	The counts are read from the NATIVE fields, never from a narrowed column, so an injected
	out-of-range count survives into the image and the refusal it caused can be investigated.
	"""
	_append_i32_column(image, _dirty_rows)
	_append_i64(image, _dirty_count)
	_append_i32_column(image, _dirty_zone_rows)
	_append_i64(image, _dirty_zone_count)
	_append_i32_column(image, _dirty_hive_rows)
	_append_i64(image, _dirty_hive_count)


func _append_membership_bytes(image: PackedByteArray) -> void:
	"""The three membership bitsets in farm, zone, hive order, each with a u32 length."""
	_append_u8_column(image, _is_dirty)
	_append_u8_column(image, _is_zone_dirty)
	_append_u8_column(image, _is_hive_dirty)


func _append_derived_bytes(image: PackedByteArray) -> void:
	"""The eight derived counters as i64, in the specified order."""
	_append_i64(image, _pending_count)
	_append_i64(image, _unmet_count)
	_append_i64(image, _requested_count)
	_append_i64(image, _demand_enabled_count)
	_append_i64(image, _demand_pending_count)
	_append_i64(image, _demand_unmet_count)
	_append_i64(image, _hive_pending_count)
	_append_i64(image, _hive_unmet_count)


func _append_diagnostic_bytes(image: PackedByteArray) -> void:
	"""The 21 outcome diagnostics in exact `_reset_counters()` assignment order."""
	_append_i64(image, _created_count)
	_append_i64(image, _completed_count)
	_append_i64(image, _cancelled_count)
	_append_i64(image, _settled_unserved_count)
	_append_i64(image, _blocker_count)
	_append_i64(image, _dropped_on_load_count)
	_append_utf8(image, _last_blocker)
	_append_i64(image, _sowing_request_count)
	_append_i64(image, _sowing_created_count)
	_append_i64(image, _sowing_started_count)
	_append_i64(image, _sowing_completed_count)
	_append_i64(image, _sowing_cancelled_count)
	_append_i64(image, _seed_committed_milli)
	_append_i64(image, _forage_created_count)
	_append_i64(image, _forage_completed_count)
	_append_i64(image, _forage_cancelled_count)
	_append_i64(image, _forage_claimed_milli)
	_append_i64(image, _hive_created_count)
	_append_i64(image, _hive_completed_count)
	_append_i64(image, _hive_cancelled_count)
	_append_i64(image, _hive_settled_unserved_count)


func _append_u8_column(image: PackedByteArray, column: PackedByteArray) -> void:
	"""Append one u8 column as u32 element count then its raw bytes."""
	_append_u32(image, column.size())
	image.append_array(column)


func _append_i32_column(image: PackedByteArray, column: PackedInt32Array) -> void:
	"""Append one i32 column as u32 element count then its raw little-endian bytes."""
	_append_u32(image, column.size())
	image.append_array(column.to_byte_array())


func _append_i64_column(image: PackedByteArray, column: PackedInt64Array) -> void:
	"""Append one i64 column as u32 element count then its raw little-endian bytes."""
	_append_u32(image, column.size())
	image.append_array(column.to_byte_array())


func _append_u32(image: PackedByteArray, value: int) -> void:
	"""Append one little-endian u32 length. Every length here is a bounded array size."""
	image.append_array(PackedInt32Array([value]).to_byte_array())


func _append_i64(image: PackedByteArray, value: int) -> void:
	"""Append one little-endian SIGNED i64, so no native counter is narrowed by the image."""
	image.append_array(PackedInt64Array([value]).to_byte_array())


func _append_utf8(image: PackedByteArray, text: StringName) -> void:
	"""Append one StringName as u32 UTF-8 byte length then its UTF-8 bytes."""
	var encoded: PackedByteArray = String(text).to_utf8_buffer()
	_append_u32(image, encoded.size())
	image.append_array(encoded)
