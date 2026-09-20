# SAVE-CLAIMS-R01 v2 -- APPEND FRAGMENT for godot/scripts/core/fishing.gd.
#
# This file is not a script of its own: it carries no `extends`, no preload and no redefinition
# of any existing fishing.gd member. Append it verbatim to the end of fishing.gd.
#
# It installs ONLY the seven section 7 FishingEffortClaim columns and their derived live count.
# Section 4's habitats and stocks, `_habitat_effort_used`, `_effort_total_scratch`, `_pending_*`,
# `_math*`, `_owns_directory` and every existing diagnostic are untouched, and no existing
# clearer, writer, rebuilder, aggregate validator, purge, release or hot mutator is called.
# The returned bool and the new diagnostic describe STRUCTURAL ADMISSION, not a reconciled
# world: actual row/Directory/Job association, reference liveness, habitat presence, per-habitat
# effort capacity and checked aggregate totals against SAVED section 4 columns all remain the
# coordinator's obligation under SAVE-CLAIM-RECONCILIATION.

# --- SAVE-CLAIMS-R01 v2: the FishingEffortClaim column block -------------------------------------

const COLUMN_FISH_CLAIM_SHAPE: StringName = &"COLUMN_FISH_CLAIM_SHAPE"
const COLUMN_FISH_CLAIM_OCCUPANCY: StringName = &"COLUMN_FISH_CLAIM_OCCUPANCY"
const COLUMN_FISH_CLAIM_BLANK: StringName = &"COLUMN_FISH_CLAIM_BLANK"
const COLUMN_FISH_CLAIM_REF: StringName = &"COLUMN_FISH_CLAIM_REF"
const COLUMN_FISH_CLAIM_SLOT_COUNT: StringName = &"COLUMN_FISH_CLAIM_SLOT_COUNT"
const COLUMN_FISH_CLAIM_SOURCE_COUNT: StringName = &"COLUMN_FISH_CLAIM_SOURCE_COUNT"

## The exact blank a released claim row carries, spelled from the directory's own empty values.
const CLAIM_COLUMN_BLANK_SLOT: int = EntityDirectory.NULL_SLOT
const CLAIM_COLUMN_BLANK_GENERATION: int = EntityDirectory.NULL_GENERATION
const CLAIM_COLUMN_BLANK_SLOT_COUNT: int = 0

## A stored habitat or Job reference is a DIRECTORY slot, not a typed row, so it is bounded by
## the directory's own capacity. The row index itself is the Expedition's typed row and is never
## looked up or reconstructed here.
const CLAIM_COLUMN_DIRECTORY_SLOT_MAX: int = EntityDirectory.DIRECTORY_CAPACITY - 1

## Code of the most recent claim-column refusal. Set only on refusal, cleared only on success,
## and separate from every existing diagnostic in this module.
var _last_claim_column_refusal: StringName = REFUSE_NONE


class EffortClaimColumns:
	"""The seven fixed claim columns, 512 cells each, with no metadata and no count field.

	The constructor takes no arguments: 512 is the native Expedition row capacity and cannot be
	reconfigured by a record. A freshly constructed record is the exact blank table.
	"""
	var effort_claim_active: PackedByteArray = PackedByteArray()
	var effort_claim_expedition_generation: PackedInt32Array = PackedInt32Array()
	var effort_claim_habitat_slot: PackedInt32Array = PackedInt32Array()
	var effort_claim_habitat_generation: PackedInt32Array = PackedInt32Array()
	var effort_claim_job_slot: PackedInt32Array = PackedInt32Array()
	var effort_claim_job_generation: PackedInt32Array = PackedInt32Array()
	var effort_claim_slot_count: PackedInt32Array = PackedInt32Array()

	func _init() -> void:
		"""Allocate all seven columns at 512 cells and fill each with its exact blank."""
		effort_claim_active.resize(FISHING_EFFORT_CLAIM_CAPACITY)
		effort_claim_expedition_generation.resize(FISHING_EFFORT_CLAIM_CAPACITY)
		effort_claim_habitat_slot.resize(FISHING_EFFORT_CLAIM_CAPACITY)
		effort_claim_habitat_generation.resize(FISHING_EFFORT_CLAIM_CAPACITY)
		effort_claim_job_slot.resize(FISHING_EFFORT_CLAIM_CAPACITY)
		effort_claim_job_generation.resize(FISHING_EFFORT_CLAIM_CAPACITY)
		effort_claim_slot_count.resize(FISHING_EFFORT_CLAIM_CAPACITY)
		effort_claim_active.fill(0)
		effort_claim_expedition_generation.fill(CLAIM_COLUMN_BLANK_GENERATION)
		effort_claim_habitat_slot.fill(CLAIM_COLUMN_BLANK_SLOT)
		effort_claim_habitat_generation.fill(CLAIM_COLUMN_BLANK_GENERATION)
		effort_claim_job_slot.fill(CLAIM_COLUMN_BLANK_SLOT)
		effort_claim_job_generation.fill(CLAIM_COLUMN_BLANK_GENERATION)
		effort_claim_slot_count.fill(CLAIM_COLUMN_BLANK_SLOT_COUNT)


class EffortClaimTally:
	"""Per-call active-row tally. A tiny native object, never a per-row one and never a Dictionary."""
	var active_rows: int = 0


func last_claim_column_refusal() -> StringName:
	"""The code of the last claim-column refusal, or the empty code after a success."""
	return _last_claim_column_refusal


func claim_column_detail() -> String:
	"""The claim-column detail: an exact echo of the code, as the Gear owner precedent does."""
	return String(_last_claim_column_refusal)


func copy_effort_claim_columns_into(out: EffortClaimColumns) -> bool:
	"""Publish seven independent duplicates of the live claim table, or refuse touching nothing.

	Order is deterministic and the first gate wins: caller null or any caller/live array length
	mismatch; the whole table's active bytes; ascending rows; and only THEN the native count
	against the rows actually counted. The source is read-only apart from this diagnostic.
	"""
	if out == null:
		return _refuse_claim_column(COLUMN_FISH_CLAIM_SHAPE)
	if not _effort_claim_record_shape_ok(out) or not _effort_claim_live_shape_ok():
		return _refuse_claim_column(COLUMN_FISH_CLAIM_SHAPE)
	var tally: EffortClaimTally = EffortClaimTally.new()
	var code: StringName = _effort_claim_payload_code(_effort_claim_active,
		_effort_claim_expedition_generation, _effort_claim_habitat_slot,
		_effort_claim_habitat_generation, _effort_claim_job_slot, _effort_claim_job_generation,
		_effort_claim_slot_count, tally)
	if code != REFUSE_NONE:
		return _refuse_claim_column(code)
	if _effort_claim_count != tally.active_rows:
		return _refuse_claim_column(COLUMN_FISH_CLAIM_SOURCE_COUNT)
	out.effort_claim_active = _effort_claim_active.duplicate()
	out.effort_claim_expedition_generation = _effort_claim_expedition_generation.duplicate()
	out.effort_claim_habitat_slot = _effort_claim_habitat_slot.duplicate()
	out.effort_claim_habitat_generation = _effort_claim_habitat_generation.duplicate()
	out.effort_claim_job_slot = _effort_claim_job_slot.duplicate()
	out.effort_claim_job_generation = _effort_claim_job_generation.duplicate()
	out.effort_claim_slot_count = _effort_claim_slot_count.duplicate()
	_last_claim_column_refusal = REFUSE_NONE
	return true


func restore_effort_claim_columns(columns: EffortClaimColumns) -> bool:
	"""Install a validated claim table and its derived count, or refuse changing nothing.

	The prior payload and the prior count are IGNORED: only the live array shapes are required.
	Every generation pair and row index is preserved verbatim, including stale ones; nothing is
	sorted, compacted, clamped or repaired. All seven arrays are duplicated privately first, so
	no fallible work remains once publication begins and a later mutation of the input cannot
	leak across this boundary.
	"""
	if columns == null:
		return _refuse_claim_column(COLUMN_FISH_CLAIM_SHAPE)
	if not _effort_claim_record_shape_ok(columns) or not _effort_claim_live_shape_ok():
		return _refuse_claim_column(COLUMN_FISH_CLAIM_SHAPE)
	var tally: EffortClaimTally = EffortClaimTally.new()
	var code: StringName = _effort_claim_payload_code(columns.effort_claim_active,
		columns.effort_claim_expedition_generation, columns.effort_claim_habitat_slot,
		columns.effort_claim_habitat_generation, columns.effort_claim_job_slot,
		columns.effort_claim_job_generation, columns.effort_claim_slot_count, tally)
	if code != REFUSE_NONE:
		return _refuse_claim_column(code)
	var active: PackedByteArray = columns.effort_claim_active.duplicate()
	var expedition_generation: PackedInt32Array = \
		columns.effort_claim_expedition_generation.duplicate()
	var habitat_slot: PackedInt32Array = columns.effort_claim_habitat_slot.duplicate()
	var habitat_generation: PackedInt32Array = columns.effort_claim_habitat_generation.duplicate()
	var job_slot: PackedInt32Array = columns.effort_claim_job_slot.duplicate()
	var job_generation: PackedInt32Array = columns.effort_claim_job_generation.duplicate()
	var slot_count: PackedInt32Array = columns.effort_claim_slot_count.duplicate()
	_effort_claim_active = active
	_effort_claim_expedition_generation = expedition_generation
	_effort_claim_habitat_slot = habitat_slot
	_effort_claim_habitat_generation = habitat_generation
	_effort_claim_job_slot = job_slot
	_effort_claim_job_generation = job_generation
	_effort_claim_slot_count = slot_count
	_effort_claim_count = tally.active_rows
	_last_claim_column_refusal = REFUSE_NONE
	return true


func _effort_claim_record_shape_ok(columns: EffortClaimColumns) -> bool:
	"""True when all SEVEN caller arrays are 512 cells. Checked before anything indexes them."""
	return columns.effort_claim_active.size() == FISHING_EFFORT_CLAIM_CAPACITY \
		and columns.effort_claim_expedition_generation.size() == FISHING_EFFORT_CLAIM_CAPACITY \
		and columns.effort_claim_habitat_slot.size() == FISHING_EFFORT_CLAIM_CAPACITY \
		and columns.effort_claim_habitat_generation.size() == FISHING_EFFORT_CLAIM_CAPACITY \
		and columns.effort_claim_job_slot.size() == FISHING_EFFORT_CLAIM_CAPACITY \
		and columns.effort_claim_job_generation.size() == FISHING_EFFORT_CLAIM_CAPACITY \
		and columns.effort_claim_slot_count.size() == FISHING_EFFORT_CLAIM_CAPACITY


func _effort_claim_live_shape_ok() -> bool:
	"""True when all seven LIVE claim arrays are 512 cells. No other section array is read."""
	return _effort_claim_active.size() == FISHING_EFFORT_CLAIM_CAPACITY \
		and _effort_claim_expedition_generation.size() == FISHING_EFFORT_CLAIM_CAPACITY \
		and _effort_claim_habitat_slot.size() == FISHING_EFFORT_CLAIM_CAPACITY \
		and _effort_claim_habitat_generation.size() == FISHING_EFFORT_CLAIM_CAPACITY \
		and _effort_claim_job_slot.size() == FISHING_EFFORT_CLAIM_CAPACITY \
		and _effort_claim_job_generation.size() == FISHING_EFFORT_CLAIM_CAPACITY \
		and _effort_claim_slot_count.size() == FISHING_EFFORT_CLAIM_CAPACITY


func _effort_claim_payload_code(active: PackedByteArray,
		expedition_generation: PackedInt32Array, habitat_slot: PackedInt32Array,
		habitat_generation: PackedInt32Array, job_slot: PackedInt32Array,
		job_generation: PackedInt32Array, slot_count: PackedInt32Array,
		tally: EffortClaimTally) -> StringName:
	"""The one payload validator, over seven typed arrays. REFUSE_NONE leaves the tally usable.

	Every active byte is validated across the WHOLE table before any per-row field is read, so a
	single stray flag cannot be masked by an earlier row's blank or field failure. Active rows
	are then validated in wire order: the Expedition generation the row's typed identity is
	paired with, the habitat reference, the Job reference and the slot count. No directory lookup
	and no per-habitat capacity lookup occurs here.
	"""
	for row: int in FISHING_EFFORT_CLAIM_CAPACITY:
		if active[row] > 1:
			return COLUMN_FISH_CLAIM_OCCUPANCY
	var counted: int = 0
	var slot_ceiling: int = _max_effort_slot_capacity()
	for row: int in FISHING_EFFORT_CLAIM_CAPACITY:
		if active[row] == 0:
			if expedition_generation[row] != CLAIM_COLUMN_BLANK_GENERATION \
					or habitat_slot[row] != CLAIM_COLUMN_BLANK_SLOT \
					or habitat_generation[row] != CLAIM_COLUMN_BLANK_GENERATION \
					or job_slot[row] != CLAIM_COLUMN_BLANK_SLOT \
					or job_generation[row] != CLAIM_COLUMN_BLANK_GENERATION \
					or slot_count[row] != CLAIM_COLUMN_BLANK_SLOT_COUNT:
				return COLUMN_FISH_CLAIM_BLANK
			continue
		counted += 1
		if expedition_generation[row] <= 0:
			return COLUMN_FISH_CLAIM_REF
		if habitat_slot[row] < 0 or habitat_slot[row] > CLAIM_COLUMN_DIRECTORY_SLOT_MAX:
			return COLUMN_FISH_CLAIM_REF
		if habitat_generation[row] <= 0:
			return COLUMN_FISH_CLAIM_REF
		if job_slot[row] < 0 or job_slot[row] > CLAIM_COLUMN_DIRECTORY_SLOT_MAX:
			return COLUMN_FISH_CLAIM_REF
		if job_generation[row] <= 0:
			return COLUMN_FISH_CLAIM_REF
		if slot_count[row] < 1 or slot_count[row] > slot_ceiling:
			return COLUMN_FISH_CLAIM_SLOT_COUNT
	tally.active_rows = counted
	return REFUSE_NONE


static func _max_effort_slot_capacity() -> int:
	"""The largest existing habitat effort capacity, read off EFFORT_SLOTS_BY_TYPE itself.

	A deliberately stronger owner gate than the codec's `>= 1`, and NOT a new gameplay cap: it
	is derived by integer iteration over the constants every existing public habitat write
	already uses, allocating no array and sorting nothing.
	"""
	var largest: int = 0
	for habitat_type: int in HABITAT_TYPE_COUNT:
		if EFFORT_SLOTS_BY_TYPE[habitat_type] > largest:
			largest = EFFORT_SLOTS_BY_TYPE[habitat_type]
	return largest


func _refuse_claim_column(code: StringName) -> bool:
	"""Record one claim-column refusal and return false. Changes no other field."""
	_last_claim_column_refusal = code
	return false
