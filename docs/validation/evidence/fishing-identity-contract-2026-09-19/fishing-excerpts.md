# Immutable fishing excerpts

## Lines 575–598
```gdscript
var _stock_habitat_generation: PackedInt32Array = PackedInt32Array()
var _stock_species_id: PackedInt32Array = PackedInt32Array()
var _stock_population_milli: PackedInt64Array = PackedInt64Array()
var _stock_capacity_milli: PackedInt64Array = PackedInt64Array()
var _stock_harvested_today_milli: PackedInt64Array = PackedInt64Array()
var _stock_closed: PackedByteArray = PackedByteArray()
## ADDED COLUMN, see the header: REQ-SET-048's 30-down/40-up hysteresis needs one bit of memory.
var _stock_restocking: PackedByteArray = PackedByteArray()

# --- FishingEffortClaim columns, indexed by EXPEDITION TYPED ROW (ruling §5) --------------------------

var _effort_claim_active: PackedByteArray = PackedByteArray()
var _effort_claim_expedition_generation: PackedInt32Array = PackedInt32Array()
var _effort_claim_habitat_slot: PackedInt32Array = PackedInt32Array()
var _effort_claim_habitat_generation: PackedInt32Array = PackedInt32Array()
var _effort_claim_job_slot: PackedInt32Array = PackedInt32Array()
var _effort_claim_job_generation: PackedInt32Array = PackedInt32Array()
var _effort_claim_slot_count: PackedInt32Array = PackedInt32Array()
var _effort_claim_count: int = 0

# --- scratch (not simulation state) -------------------------------------------------------------------

## Checked-arithmetic scratch for int_math's `_into` forms. Nothing here invokes a callback or a
## signal, so no public operation can re-enter while it holds a live value.
```


## Lines 694–724
```gdscript
			assert(SPECIES_HABITAT_TYPE[species] == habitat_type,
				"the habitat-to-species binding must read back to the same habitat")


func _allocate_columns() -> void:
	"""The only place that sizes a packed array (ARCH-MEM-005: allocate once)."""
	_allocate_habitat_columns()
	_allocate_stock_columns()
	_allocate_effort_claim_columns()


func _allocate_effort_claim_columns() -> void:
	"""Size ruling §5's claim slice at one row per Expedition, plus its 32-entry total scratch."""
	_effort_claim_active.resize(FISHING_EFFORT_CLAIM_CAPACITY)
	_effort_claim_expedition_generation.resize(FISHING_EFFORT_CLAIM_CAPACITY)
	_effort_claim_habitat_slot.resize(FISHING_EFFORT_CLAIM_CAPACITY)
	_effort_claim_habitat_generation.resize(FISHING_EFFORT_CLAIM_CAPACITY)
	_effort_claim_job_slot.resize(FISHING_EFFORT_CLAIM_CAPACITY)
	_effort_claim_job_generation.resize(FISHING_EFFORT_CLAIM_CAPACITY)
	_effort_claim_slot_count.resize(FISHING_EFFORT_CLAIM_CAPACITY)
	_effort_total_scratch.resize(FISH_HABITAT_CAPACITY)


func _allocate_habitat_columns() -> void:
	"""Size the FishHabitat columns and the live-habitat index at 32 rows."""
	_habitat_present.resize(FISH_HABITAT_CAPACITY)
	_habitat_type.resize(FISH_HABITAT_CAPACITY)
	_habitat_zone_slot.resize(FISH_HABITAT_CAPACITY)
	_habitat_zone_generation.resize(FISH_HABITAT_CAPACITY)
	_habitat_effort_slots.resize(FISH_HABITAT_CAPACITY)
	_habitat_pollution.resize(FISH_HABITAT_CAPACITY)
```


## Lines 758–781
```gdscript
	if _owns_directory:
		_directory.clear()


func _clear_effort_claim_columns() -> void:
	"""Null and zero every claim row (ruling §5: "Null/zero unused rows")."""
	_effort_claim_active.fill(0)
	_effort_claim_expedition_generation.fill(EntityDirectory.NULL_GENERATION)
	_effort_claim_habitat_slot.fill(EntityDirectory.NULL_SLOT)
	_effort_claim_habitat_generation.fill(EntityDirectory.NULL_GENERATION)
	_effort_claim_job_slot.fill(EntityDirectory.NULL_SLOT)
	_effort_claim_job_generation.fill(EntityDirectory.NULL_GENERATION)
	_effort_claim_slot_count.fill(0)
	_effort_total_scratch.fill(0)
	_effort_claim_count = 0
	_pending_claim_row = -1
	_pending_habitat_slot = -1


func _release_live_habitats() -> void:
	"""Destroy the directory slot of every live habitat, so a clear leaks no allocation."""
	for index: int in _live_habitat_count:
		var slot: int = _live_habitat_slots[index]
		if slot < 0 or slot >= FISH_HABITAT_CAPACITY or _habitat_present[slot] != 1:
```


## Lines 1478–1548
```gdscript


func _refuse_effort_owner(expedition_ref: Vector2i, job_ref: Vector2i) -> StringName:
	"""REFUSE_NONE when this Expedition row is free to claim and this Job may own the claim.

	The Expedition reference is validated THROUGH THE DIRECTORY FIRST and only then against the
	generation stored on its row, which is what distinguishes "this expedition already holds a
	claim" from "a previous expedition left one on the row this one reuses".
	"""
	if _jobs == null:
		return REFUSE_NO_JOB_STORE
	if not _directory.is_valid_of_kind(expedition_ref, EntityDirectory.KIND_EXPEDITION):
		return REFUSE_EXPEDITION_NOT_PRESENT
	var row: int = _directory.get_typed_row(expedition_ref)
	if _effort_claim_active[row] == 1:
		if _effort_claim_expedition_generation[row] == expedition_ref.y:
			return REFUSE_EFFORT_CLAIM_PRESENT
		return REFUSE_EFFORT_CLAIM_STALE
	_pending_claim_row = row
	return _refuse_effort_claim_job(job_ref)


func _refuse_effort_claim_job(job_ref: Vector2i) -> StringName:
	"""REFUSE_NONE when `job_ref` is a live Job that may own a claim (decision 0017's coordinator).

	A MEMBER Job is refused: its coordinator owns the cycle, which is exactly what stops
	cancelling one party member from releasing the whole cycle's effort slots.
	"""
	if not _directory.is_valid_of_kind(job_ref, EntityDirectory.KIND_JOB):
		return REFUSE_JOB_NOT_PRESENT
	var job_slot: int = _directory.get_typed_row(job_ref)
	if not _jobs.is_job_present(job_slot):
		return REFUSE_JOB_NOT_PRESENT
	if _jobs.is_member(job_slot):
		return REFUSE_JOB_IS_MEMBER
	return REFUSE_NONE


func _write_effort_claim(row: int, expedition_ref: Vector2i, job_ref: Vector2i,
		habitat_ref: Vector2i, slot_count: int) -> void:
	"""Write every column of one claim row and publish `active` last."""
	_effort_claim_expedition_generation[row] = expedition_ref.y
	_effort_claim_habitat_slot[row] = habitat_ref.x
	_effort_claim_habitat_generation[row] = habitat_ref.y
	_effort_claim_job_slot[row] = job_ref.x
	_effort_claim_job_generation[row] = job_ref.y
	_effort_claim_slot_count[row] = slot_count
	_effort_claim_active[row] = 1
	_effort_claim_count += 1


func _clear_effort_claim_row(row: int) -> void:
	"""Return one claim row to the null/zero state unused rows carry."""
	_effort_claim_active[row] = 0
	_effort_claim_expedition_generation[row] = EntityDirectory.NULL_GENERATION
	_effort_claim_habitat_slot[row] = EntityDirectory.NULL_SLOT
	_effort_claim_habitat_generation[row] = EntityDirectory.NULL_GENERATION
	_effort_claim_job_slot[row] = EntityDirectory.NULL_SLOT
	_effort_claim_job_generation[row] = EntityDirectory.NULL_GENERATION
	_effort_claim_slot_count[row] = 0
	_effort_claim_count -= 1


func release_effort_slots(expedition_ref: Vector2i) -> OpResult:
	"""Give back exactly this cycle's slots, exactly once. Returns the slots still taken.

	A second release finds no active claim and refuses, and a reference whose stored generation
	disagrees refuses too, so neither a double nor a stale call can free somebody else's slots.
	"""
	if not effort_claim_row_into(expedition_ref, _math):
		return _refuse(StringName(_math.error))
```


## Lines 1618–1667
```gdscript
	return out


func effort_claim_row_into(expedition_ref: Vector2i, out: IntMath.IntResult) -> bool:
	"""Non-allocating effort_claim_row_of(): validate through the directory, then the row.

	Ruling §5's two-step ownership test. The directory settles that the Expedition reference is
	live; the stored generation then settles that THIS expedition wrote the claim, and not a
	previous one whose typed row it now occupies.
	"""
	if not _directory.is_valid_of_kind(expedition_ref, EntityDirectory.KIND_EXPEDITION):
		return out.refuse(String(REFUSE_EXPEDITION_NOT_PRESENT))
	var row: int = _directory.get_typed_row(expedition_ref)
	if _effort_claim_active[row] != 1:
		return out.refuse(String(REFUSE_NO_EFFORT_CLAIM))
	if _effort_claim_expedition_generation[row] != expedition_ref.y:
		return out.refuse(String(REFUSE_EFFORT_CLAIM_STALE))
	return out.succeed(row)


func effort_claim_habitat_ref_of(row: int) -> Vector2i:
	"""The habitat a live claim holds slots in, or the §4.1 null reference `(-1, 0)`."""
	if not is_effort_claim_active(row):
		return NULL_REF
	return Vector2i(_effort_claim_habitat_slot[row], _effort_claim_habitat_generation[row])


func effort_claim_job_ref_of(row: int) -> Vector2i:
	"""The coordinator Job owning a live claim, or the §4.1 null reference `(-1, 0)`."""
	if not is_effort_claim_active(row):
		return NULL_REF
	return Vector2i(_effort_claim_job_slot[row], _effort_claim_job_generation[row])


func effort_claim_expedition_ref_of(row: int) -> Vector2i:
	"""The Expedition owning a live claim, rebuilt from the directory's reverse map.

	The claim slice stores only the generation (ruling §5's six I32 columns); the slot comes back
	from EntityDirectory.owner_slot_of_typed_row(), which reads a column that already exists.
	"""
	if not is_effort_claim_active(row):
		return NULL_REF
	var slot: int = _directory.owner_slot_of_typed_row(EntityDirectory.KIND_EXPEDITION, row)
	if slot == EntityDirectory.NULL_SLOT:
		return NULL_REF
	return Vector2i(slot, _effort_claim_expedition_generation[row])


func effort_claim_slot_count_of(row: int) -> IntMath.IntResult:
	"""How many effort slots one live claim holds."""
```


## Lines 1727–1795
```gdscript


func _accumulate_effort_totals() -> StringName:
	"""Total every live claim into `_effort_total_scratch`, validating each one on the way.

	REFUSE_NONE leaves a complete per-habitat occupancy in the scratch column and the live claim
	count in `_effort_claim_count`; any refusal leaves both meaningless and the caller applies
	neither.
	"""
	if _jobs == null:
		return REFUSE_NO_JOB_STORE
	_effort_total_scratch.fill(0)
	var counted: int = 0
	for row: int in FISHING_EFFORT_CLAIM_CAPACITY:
		if _effort_claim_active[row] != 1:
			continue
		var code: StringName = _refuse_stored_effort_claim(row)
		if code != REFUSE_NONE:
			return code
		counted += 1
		var slot: int = _math_b.value
		_effort_total_scratch[slot] += _effort_claim_slot_count[row]
		if _effort_total_scratch[slot] > _habitat_effort_slots[slot]:
			return REFUSE_AGGREGATE_MISMATCH
	_effort_claim_count = counted
	return REFUSE_NONE


func _refuse_stored_effort_claim(row: int) -> StringName:
	"""REFUSE_NONE when one stored claim's owners are all live and agree. Leaves its habitat row
	in `_math_b` for the accumulation that follows."""
	var expedition_ref: Vector2i = effort_claim_expedition_ref_of(row)
	if not _directory.is_valid_of_kind(expedition_ref, EntityDirectory.KIND_EXPEDITION):
		return REFUSE_EXPEDITION_NOT_PRESENT
	if _directory.get_typed_row(expedition_ref) != row:
		return REFUSE_EFFORT_CLAIM_STALE
	var code: StringName = _refuse_effort_claim_job(effort_claim_job_ref_of(row))
	if code != REFUSE_NONE:
		return code
	if not habitat_slot_of_into(effort_claim_habitat_ref_of(row), _math_b):
		return StringName(_math_b.error)
	if _effort_claim_slot_count[row] <= 0:
		return REFUSE_INVALID_SLOT_COUNT
	return REFUSE_NONE


func purge_stale_effort_claims() -> OpResult:
	"""Release every claim whose Expedition is gone. Returns how many were released.

	A destroyed expedition cannot call release_effort_slots() for itself, so without this sweep
	its slots would stay taken forever. Nothing else releases a claim on somebody's behalf.
	"""
	var released: int = 0
	for row: int in FISHING_EFFORT_CLAIM_CAPACITY:
		if _effort_claim_active[row] != 1:
			continue
		var expedition_ref: Vector2i = effort_claim_expedition_ref_of(row)
		if _directory.is_valid_of_kind(expedition_ref, EntityDirectory.KIND_EXPEDITION) \
				and _directory.get_typed_row(expedition_ref) == row:
			continue
		_release_effort_claim_row(row)
		released += 1
	return _succeed(released, NULL_REF)


func release_cancelled_effort_claims() -> OpResult:
	"""Release every claim whose owning coordinator Job is gone or CANCELLED. Returns the count.

	Ruling §5: cancellation releases exactly that owner's slots, exactly once. A cancelled MEMBER
```


## Lines 1844–1856
```gdscript
func effort_claim_payload_bytes() -> int:
	"""Ruling §5's 12800-byte claim slice, measured off the real column sizes."""
	return (_effort_claim_active.size() * BYTES_PER_BYTE_COLUMN
		+ (_effort_claim_expedition_generation.size() + _effort_claim_habitat_slot.size()
			+ _effort_claim_habitat_generation.size() + _effort_claim_job_slot.size()
			+ _effort_claim_job_generation.size() + _effort_claim_slot_count.size())
			* BYTES_PER_INT32)


func fishing_state_addition_bytes() -> int:
	"""Decision 0027's ratified 256 bytes: effort_used 128, restocking 96, intensive_harvest 32.

	It EXCLUDES the claim slice reported by effort_claim_payload_bytes(), which ruling §5 states
```


## Lines 2750–2988
```gdscript
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
```
