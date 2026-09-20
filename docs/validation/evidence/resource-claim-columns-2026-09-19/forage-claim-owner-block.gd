# SAVE-CLAIMS-R01 v2 -- APPEND FRAGMENT for godot/scripts/core/forage.gd.
#
# This file is not a script of its own: it carries no `extends`, no preload and no redefinition
# of any existing forage.gd member. Append it verbatim to the end of forage.gd.
#
# It installs ONLY the eleven section 7 ForageClaim columns and their derived live count.
# Sections 1, 4 and 5 -- the tile head column, the zones, the patches and the link arena --
# are untouched, as are `_zone_quota_reserved_milli`, `_zone_harvested_today_milli`, the live
# zone list, `_math*`, `_pending_*`, `_owns_directory` and the existing section 1 diagnostics,
# which remain an independent interface. No existing clearer, writer, rebuilder, reconciler,
# purge, release, midnight sweep or order-key refresh is called, so the canonical created tick
# and persistent id of each claim survive verbatim even when the current Job fields differ.
# These keys are canonical state, not caches.
#
# The returned bool and the new diagnostic describe STRUCTURAL ADMISSION, not a reconciled
# world: zone presence, per-zone quota totals against SAVED section 4/5 values, Job association
# and order-key provenance -- including the zero persistent id anomaly for a live Job -- all
# remain the coordinator's obligation under SAVE-CLAIM-RECONCILIATION.

# --- SAVE-CLAIMS-R01 v2: the ForageClaim column block --------------------------------------------

const COLUMN_FORAGE_CLAIM_SHAPE: StringName = &"COLUMN_FORAGE_CLAIM_SHAPE"
const COLUMN_FORAGE_CLAIM_OCCUPANCY: StringName = &"COLUMN_FORAGE_CLAIM_OCCUPANCY"
const COLUMN_FORAGE_CLAIM_BLANK: StringName = &"COLUMN_FORAGE_CLAIM_BLANK"
const COLUMN_FORAGE_CLAIM_REF: StringName = &"COLUMN_FORAGE_CLAIM_REF"
const COLUMN_FORAGE_CLAIM_KIND: StringName = &"COLUMN_FORAGE_CLAIM_KIND"
const COLUMN_FORAGE_CLAIM_QUANTITY: StringName = &"COLUMN_FORAGE_CLAIM_QUANTITY"
const COLUMN_FORAGE_CLAIM_ORDER_KEY: StringName = &"COLUMN_FORAGE_CLAIM_ORDER_KEY"
const COLUMN_FORAGE_CLAIM_SOURCE_COUNT: StringName = &"COLUMN_FORAGE_CLAIM_SOURCE_COUNT"

## The exact blank a released claim row carries.
const CLAIM_COLUMN_BLANK_SLOT: int = EntityDirectory.NULL_SLOT
const CLAIM_COLUMN_BLANK_GENERATION: int = EntityDirectory.NULL_GENERATION
const CLAIM_COLUMN_BLANK_KIND: int = -1
const CLAIM_COLUMN_BLANK_I64: int = 0

## Each stored zone reference is a DIRECTORY slot, not a claim row and not a typed zone row; the
## row index itself is the owning Job's typed row, so the stored Job slot is NOT equal to it.
const CLAIM_COLUMN_DIRECTORY_SLOT_MAX: int = EntityDirectory.DIRECTORY_CAPACITY - 1

## Code of the most recent claim-column refusal. Set only on refusal, cleared only on success,
## and deliberately separate from this module's existing section 1 diagnostic.
var _last_claim_column_refusal: StringName = REFUSE_NONE


class ForageClaimColumns:
	"""The eleven fixed claim columns, 8192 cells each, with no metadata and no count field.

	The constructor takes no arguments: 8192 is the native Job row capacity and cannot be
	reconfigured by a record. A freshly constructed record is the exact blank table.
	"""
	var claim_active: PackedByteArray = PackedByteArray()
	var claim_job_slot: PackedInt32Array = PackedInt32Array()
	var claim_job_generation: PackedInt32Array = PackedInt32Array()
	var claim_designation_slot: PackedInt32Array = PackedInt32Array()
	var claim_designation_generation: PackedInt32Array = PackedInt32Array()
	var claim_basin_slot: PackedInt32Array = PackedInt32Array()
	var claim_basin_generation: PackedInt32Array = PackedInt32Array()
	var claim_patch_kind: PackedInt32Array = PackedInt32Array()
	var claim_remaining_milli: PackedInt64Array = PackedInt64Array()
	var claim_created_tick: PackedInt64Array = PackedInt64Array()
	var claim_persistent_id: PackedInt64Array = PackedInt64Array()

	func _init() -> void:
		"""Allocate all eleven columns at 8192 cells and fill each with its exact blank."""
		claim_active.resize(FORAGE_CLAIM_CAPACITY)
		claim_job_slot.resize(FORAGE_CLAIM_CAPACITY)
		claim_job_generation.resize(FORAGE_CLAIM_CAPACITY)
		claim_designation_slot.resize(FORAGE_CLAIM_CAPACITY)
		claim_designation_generation.resize(FORAGE_CLAIM_CAPACITY)
		claim_basin_slot.resize(FORAGE_CLAIM_CAPACITY)
		claim_basin_generation.resize(FORAGE_CLAIM_CAPACITY)
		claim_patch_kind.resize(FORAGE_CLAIM_CAPACITY)
		claim_remaining_milli.resize(FORAGE_CLAIM_CAPACITY)
		claim_created_tick.resize(FORAGE_CLAIM_CAPACITY)
		claim_persistent_id.resize(FORAGE_CLAIM_CAPACITY)
		claim_active.fill(0)
		claim_job_slot.fill(CLAIM_COLUMN_BLANK_SLOT)
		claim_job_generation.fill(CLAIM_COLUMN_BLANK_GENERATION)
		claim_designation_slot.fill(CLAIM_COLUMN_BLANK_SLOT)
		claim_designation_generation.fill(CLAIM_COLUMN_BLANK_GENERATION)
		claim_basin_slot.fill(CLAIM_COLUMN_BLANK_SLOT)
		claim_basin_generation.fill(CLAIM_COLUMN_BLANK_GENERATION)
		claim_patch_kind.fill(CLAIM_COLUMN_BLANK_KIND)
		claim_remaining_milli.fill(CLAIM_COLUMN_BLANK_I64)
		claim_created_tick.fill(CLAIM_COLUMN_BLANK_I64)
		claim_persistent_id.fill(CLAIM_COLUMN_BLANK_I64)


class ForageClaimTally:
	"""Per-call active-row tally. A tiny native object, never a per-row one and never a Dictionary."""
	var active_rows: int = 0


func last_claim_column_refusal() -> StringName:
	"""The code of the last claim-column refusal, or the empty code after a success."""
	return _last_claim_column_refusal


func claim_column_detail() -> String:
	"""The claim-column detail: an exact echo of the code, as the Gear owner precedent does."""
	return String(_last_claim_column_refusal)


func copy_forage_claim_columns_into(out: ForageClaimColumns) -> bool:
	"""Publish eleven independent duplicates of the live claim table, or refuse touching nothing.

	Order is deterministic and the first gate wins: caller null or any caller/live array length
	mismatch; the whole table's active bytes; ascending rows; and only THEN the native count
	against the rows actually counted. The source is read-only apart from this diagnostic.
	"""
	if out == null:
		return _refuse_claim_column(COLUMN_FORAGE_CLAIM_SHAPE)
	if not _forage_claim_record_shape_ok(out) or not _forage_claim_live_shape_ok():
		return _refuse_claim_column(COLUMN_FORAGE_CLAIM_SHAPE)
	var tally: ForageClaimTally = ForageClaimTally.new()
	var code: StringName = _forage_claim_payload_code(_claim_active, _claim_job_slot,
		_claim_job_generation, _claim_designation_slot, _claim_designation_generation,
		_claim_basin_slot, _claim_basin_generation, _claim_patch_kind, _claim_remaining_milli,
		_claim_created_tick, _claim_persistent_id, tally)
	if code != REFUSE_NONE:
		return _refuse_claim_column(code)
	if _claim_count != tally.active_rows:
		return _refuse_claim_column(COLUMN_FORAGE_CLAIM_SOURCE_COUNT)
	out.claim_active = _claim_active.duplicate()
	out.claim_job_slot = _claim_job_slot.duplicate()
	out.claim_job_generation = _claim_job_generation.duplicate()
	out.claim_designation_slot = _claim_designation_slot.duplicate()
	out.claim_designation_generation = _claim_designation_generation.duplicate()
	out.claim_basin_slot = _claim_basin_slot.duplicate()
	out.claim_basin_generation = _claim_basin_generation.duplicate()
	out.claim_patch_kind = _claim_patch_kind.duplicate()
	out.claim_remaining_milli = _claim_remaining_milli.duplicate()
	out.claim_created_tick = _claim_created_tick.duplicate()
	out.claim_persistent_id = _claim_persistent_id.duplicate()
	_last_claim_column_refusal = REFUSE_NONE
	return true


func restore_forage_claim_columns(cols: ForageClaimColumns) -> bool:
	"""Install a validated claim table and its derived count, or refuse changing nothing.

	The prior payload and the prior count are IGNORED: only the live array shapes are required.
	Every generation pair, row index and ordering key is preserved verbatim, including stale
	generations and a zero created tick or persistent id; nothing is sorted, compacted, clamped,
	masked or repaired, and no reservation aggregate or order key is rewritten. All eleven arrays
	are duplicated privately first, so no fallible work remains once publication begins and a
	later mutation of the input cannot leak across this boundary.
	"""
	if cols == null:
		return _refuse_claim_column(COLUMN_FORAGE_CLAIM_SHAPE)
	if not _forage_claim_record_shape_ok(cols) or not _forage_claim_live_shape_ok():
		return _refuse_claim_column(COLUMN_FORAGE_CLAIM_SHAPE)
	var tally: ForageClaimTally = ForageClaimTally.new()
	var code: StringName = _forage_claim_payload_code(cols.claim_active, cols.claim_job_slot,
		cols.claim_job_generation, cols.claim_designation_slot,
		cols.claim_designation_generation, cols.claim_basin_slot, cols.claim_basin_generation,
		cols.claim_patch_kind, cols.claim_remaining_milli, cols.claim_created_tick,
		cols.claim_persistent_id, tally)
	if code != REFUSE_NONE:
		return _refuse_claim_column(code)
	var active: PackedByteArray = cols.claim_active.duplicate()
	var job_slot: PackedInt32Array = cols.claim_job_slot.duplicate()
	var job_generation: PackedInt32Array = cols.claim_job_generation.duplicate()
	var designation_slot: PackedInt32Array = cols.claim_designation_slot.duplicate()
	var designation_generation: PackedInt32Array = cols.claim_designation_generation.duplicate()
	var basin_slot: PackedInt32Array = cols.claim_basin_slot.duplicate()
	var basin_generation: PackedInt32Array = cols.claim_basin_generation.duplicate()
	var patch_kind: PackedInt32Array = cols.claim_patch_kind.duplicate()
	var remaining_milli: PackedInt64Array = cols.claim_remaining_milli.duplicate()
	var created_tick: PackedInt64Array = cols.claim_created_tick.duplicate()
	var persistent_id: PackedInt64Array = cols.claim_persistent_id.duplicate()
	_claim_active = active
	_claim_job_slot = job_slot
	_claim_job_generation = job_generation
	_claim_designation_slot = designation_slot
	_claim_designation_generation = designation_generation
	_claim_basin_slot = basin_slot
	_claim_basin_generation = basin_generation
	_claim_patch_kind = patch_kind
	_claim_remaining_milli = remaining_milli
	_claim_created_tick = created_tick
	_claim_persistent_id = persistent_id
	_claim_count = tally.active_rows
	_last_claim_column_refusal = REFUSE_NONE
	return true


func _forage_claim_record_shape_ok(cols: ForageClaimColumns) -> bool:
	"""True when all ELEVEN caller arrays are 8192 cells. Checked before anything indexes them."""
	return cols.claim_active.size() == FORAGE_CLAIM_CAPACITY \
		and cols.claim_job_slot.size() == FORAGE_CLAIM_CAPACITY \
		and cols.claim_job_generation.size() == FORAGE_CLAIM_CAPACITY \
		and cols.claim_designation_slot.size() == FORAGE_CLAIM_CAPACITY \
		and cols.claim_designation_generation.size() == FORAGE_CLAIM_CAPACITY \
		and cols.claim_basin_slot.size() == FORAGE_CLAIM_CAPACITY \
		and cols.claim_basin_generation.size() == FORAGE_CLAIM_CAPACITY \
		and cols.claim_patch_kind.size() == FORAGE_CLAIM_CAPACITY \
		and cols.claim_remaining_milli.size() == FORAGE_CLAIM_CAPACITY \
		and cols.claim_created_tick.size() == FORAGE_CLAIM_CAPACITY \
		and cols.claim_persistent_id.size() == FORAGE_CLAIM_CAPACITY


func _forage_claim_live_shape_ok() -> bool:
	"""True when all eleven LIVE claim arrays are 8192 cells. No other section array is read."""
	return _claim_active.size() == FORAGE_CLAIM_CAPACITY \
		and _claim_job_slot.size() == FORAGE_CLAIM_CAPACITY \
		and _claim_job_generation.size() == FORAGE_CLAIM_CAPACITY \
		and _claim_designation_slot.size() == FORAGE_CLAIM_CAPACITY \
		and _claim_designation_generation.size() == FORAGE_CLAIM_CAPACITY \
		and _claim_basin_slot.size() == FORAGE_CLAIM_CAPACITY \
		and _claim_basin_generation.size() == FORAGE_CLAIM_CAPACITY \
		and _claim_patch_kind.size() == FORAGE_CLAIM_CAPACITY \
		and _claim_remaining_milli.size() == FORAGE_CLAIM_CAPACITY \
		and _claim_created_tick.size() == FORAGE_CLAIM_CAPACITY \
		and _claim_persistent_id.size() == FORAGE_CLAIM_CAPACITY


func _forage_claim_payload_code(active: PackedByteArray, job_slot: PackedInt32Array,
		job_generation: PackedInt32Array, designation_slot: PackedInt32Array,
		designation_generation: PackedInt32Array, basin_slot: PackedInt32Array,
		basin_generation: PackedInt32Array, patch_kind: PackedInt32Array,
		remaining_milli: PackedInt64Array, created_tick: PackedInt64Array,
		persistent_id: PackedInt64Array, tally: ForageClaimTally) -> StringName:
	"""The one payload validator, over eleven typed arrays. REFUSE_NONE leaves the tally usable.

	Every active byte is validated across the WHOLE table before any per-row field is read. Active
	rows are then validated in wire order: the owning Job reference, the designation reference,
	the basin reference, the patch kind, the remaining quantity and the two ordering keys.

	A remaining quantity of zero REFUSES on an active row: a claim collected to zero is closed by
	existing code, so a live zero is corruption rather than an empty promise. The upper bound is
	the existing manual quota ceiling. Nothing is clamped or masked.
	"""
	for row: int in FORAGE_CLAIM_CAPACITY:
		if active[row] > 1:
			return COLUMN_FORAGE_CLAIM_OCCUPANCY
	var counted: int = 0
	for row: int in FORAGE_CLAIM_CAPACITY:
		if active[row] == 0:
			if job_slot[row] != CLAIM_COLUMN_BLANK_SLOT \
					or job_generation[row] != CLAIM_COLUMN_BLANK_GENERATION \
					or designation_slot[row] != CLAIM_COLUMN_BLANK_SLOT \
					or designation_generation[row] != CLAIM_COLUMN_BLANK_GENERATION \
					or basin_slot[row] != CLAIM_COLUMN_BLANK_SLOT \
					or basin_generation[row] != CLAIM_COLUMN_BLANK_GENERATION \
					or patch_kind[row] != CLAIM_COLUMN_BLANK_KIND \
					or remaining_milli[row] != CLAIM_COLUMN_BLANK_I64 \
					or created_tick[row] != CLAIM_COLUMN_BLANK_I64 \
					or persistent_id[row] != CLAIM_COLUMN_BLANK_I64:
				return COLUMN_FORAGE_CLAIM_BLANK
			continue
		counted += 1
		if job_slot[row] < 0 or job_slot[row] > CLAIM_COLUMN_DIRECTORY_SLOT_MAX:
			return COLUMN_FORAGE_CLAIM_REF
		if job_generation[row] <= 0:
			return COLUMN_FORAGE_CLAIM_REF
		if designation_slot[row] < 0 \
				or designation_slot[row] > CLAIM_COLUMN_DIRECTORY_SLOT_MAX:
			return COLUMN_FORAGE_CLAIM_REF
		if designation_generation[row] <= 0:
			return COLUMN_FORAGE_CLAIM_REF
		if basin_slot[row] < 0 or basin_slot[row] > CLAIM_COLUMN_DIRECTORY_SLOT_MAX:
			return COLUMN_FORAGE_CLAIM_REF
		if basin_generation[row] <= 0:
			return COLUMN_FORAGE_CLAIM_REF
		if patch_kind[row] < 0 or patch_kind[row] >= PATCHES_PER_ZONE:
			return COLUMN_FORAGE_CLAIM_KIND
		if remaining_milli[row] < 1 or remaining_milli[row] > MANUAL_QUOTA_MAX_MILLI:
			return COLUMN_FORAGE_CLAIM_QUANTITY
		if created_tick[row] < 0 or persistent_id[row] < 0:
			return COLUMN_FORAGE_CLAIM_ORDER_KEY
	tally.active_rows = counted
	return REFUSE_NONE


func _refuse_claim_column(code: StringName) -> bool:
	"""Record one claim-column refusal and return false. Changes no other field."""
	_last_claim_column_refusal = code
	return false
