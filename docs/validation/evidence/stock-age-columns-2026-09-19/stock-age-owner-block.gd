## SAVE-AGE-R01v2 APPEND FRAGMENT for `godot/scripts/core/stock_age.gd`.
##
## This file is NOT a script of its own: it carries no `extends`, no `preload` and no copy of
## any member `stock_age.gd` already declares. The parent packet appends it verbatim to the END
## of that file. Every identifier it reads -- CONTAINER_CAPACITY, NULL_SLOT, NO_HOUR_RUN,
## STORAGE_UNDECLARED, STORAGE_CLASS_COUNT, REFUSE_NONE, the four declaration columns,
## `_declared_count`, `_last_hour_tick`, `_inventory`, `_definitions`, `_spoiled_food_id` and
## `_compost_id` -- is declared earlier in that same file.
##
## WHAT THIS ADDS: the owner half of SAVE-AGE-R01v2. StockAge publishes its four existing packed
## columns and its two scalars through a caller-owned record, and accepts the same shape back.
## It adds no persisted or derived array, no signal, no callback and no new hourly behaviour.
##
## THE COLUMN DIAGNOSTIC IS CATEGORY 3 AND SEPARATE. `_last_column_refusal` is the ONLY field
## either path writes on failure, and the only one success clears. `_last_refusal` -- the
## declaration/hour diagnostic -- is never touched here, in either direction, so an operational
## refusal cannot be overwritten by a save and a save refusal cannot be read as one.
##
## WHAT IS DELIBERATELY NOT DONE HERE. No current-container validity, crop/item meaning or
## present-day storage gate is consulted: a stale declaration is legitimate until the ordinary
## hourly sweep drops it, so capture and restore preserve stale references and the dense prefix
## ORDER exactly, with no sorting, repair, mark-all, declaration replay, `clear()` or Inventory
## mutation. The latch is PRESERVED, never inferred: `is_hour_boundary()`, the calendar and the
## aging pass are not called to validate or reconstruct it, and its domain here is only the
## structural `>= NO_HOUR_RUN` the existing codec already enforces. Stronger clock/latch/fault
## consistency is coordinator work and is not claimed by these four methods.
##
## BUSY means this store's bound Inventory reports an open or poisoned transaction; both are
## existing pure predicates over bool fields. That is NOT a claim that the Inventory journal,
## its attestation or the world as a whole is quiescent -- the full coordinator still owns those
## preconditions, and the caller must not re-enter these methods from inside an aging or
## declaration operation or any Inventory authority callback.
##
## REBINDING A DIFFERENT INVENTORY DROPS EVERY DECLARATION, so `bind_stores()` must precede
## `restore_stock_age_columns()`. This adapter never binds on a caller's behalf.

const COLUMN_STOCK_AGE_SHAPE: StringName = &"COLUMN_STOCK_AGE_SHAPE"
const COLUMN_STOCK_AGE_BINDING: StringName = &"COLUMN_STOCK_AGE_BINDING"
const COLUMN_STOCK_AGE_BUSY: StringName = &"COLUMN_STOCK_AGE_BUSY"
const COLUMN_STOCK_AGE_RECORD: StringName = &"COLUMN_STOCK_AGE_RECORD"

## The one new scalar. Category 3 diagnostic: never persisted, never derived from, and the only
## field a failed or successful column call writes.
var _last_column_refusal: StringName = REFUSE_NONE


class CanonicalColumns:
	"""A caller-owned copy of this stage's four declaration columns and two scalars.

	Allocated at the compiled CONTAINER_CAPACITY with no extent parameter, because that extent is
	read from `inventory.gd` and is not a runtime choice. `container_capacity` is carried as
	METADATA so a caller that alters it is refused rather than silently reshaped, and both
	capture and restore check it.

	This record allocates no Inventory, no item catalog and no owner instance: it is four packed
	arrays and two integers, and it holds no reference to the store it came from.
	"""
	var container_capacity: int = CONTAINER_CAPACITY
	var c_storage_class: PackedByteArray = PackedByteArray()
	var c_heated_interior: PackedByteArray = PackedByteArray()
	var c_declared_generation: PackedInt32Array = PackedInt32Array()
	var declared_slots: PackedInt32Array = PackedInt32Array()
	var declared_count: int = 0
	var last_hour_tick: int = NO_HOUR_RUN

	func _init() -> void:
		"""Allocate the four columns at the compiled extent, in the store's own empty form."""
		c_storage_class.resize(CONTAINER_CAPACITY)
		c_storage_class.fill(STORAGE_UNDECLARED)
		c_heated_interior.resize(CONTAINER_CAPACITY)
		c_heated_interior.fill(0)
		c_declared_generation.resize(CONTAINER_CAPACITY)
		c_declared_generation.fill(0)
		declared_slots.resize(CONTAINER_CAPACITY)
		declared_slots.fill(NULL_SLOT)


# --- the owner column boundary ------------------------------------------------------------------

func copy_stock_age_columns_into(out: CanonicalColumns) -> bool:
	"""Publish this stage's declarations and latch into a caller-owned record.

	GATE ORDER, fixed: the output's own null/shape, then binding, then busy, then the live
	arrays' shapes, then the live scalars' native domains, then the live rows and dense list.
	Only a fully validated source is published. A caller-supplied record of the wrong shape is
	SHAPE; a source whose own arrays or payload are wrong is RECORD, because the defect is this
	store's and not the caller's.

	The four output arrays are replaced with INDEPENDENT duplicates and the two scalars copied
	exactly. No staging record is needed because no yield or callback occurs between validation
	and publication.

	NAMED `copy_stock_age_columns_into` ON PURPOSE. The generic duck-typed
	`capture_inventory_into()` gate must not be able to mistake this owner for an Inventory, and
	those generic Inventory methods are not called from here.
	"""
	if out == null or not _columns_shape_ok(out):
		return _refuse_column(COLUMN_STOCK_AGE_SHAPE)
	if not _column_binding_ready():
		return _refuse_column(COLUMN_STOCK_AGE_BINDING)
	if _column_store_busy():
		return _refuse_column(COLUMN_STOCK_AGE_BUSY)
	if not _live_columns_shape_ok():
		return _refuse_column(COLUMN_STOCK_AGE_RECORD)
	if not _column_scalars_in_domain(_declared_count, _last_hour_tick):
		return _refuse_column(COLUMN_STOCK_AGE_RECORD)
	if not _column_payload_ok(_c_storage_class, _c_heated_interior, _c_declared_generation,
			_declared_slots, _declared_count):
		return _refuse_column(COLUMN_STOCK_AGE_RECORD)
	out.container_capacity = CONTAINER_CAPACITY
	out.c_storage_class = _c_storage_class.duplicate()
	out.c_heated_interior = _c_heated_interior.duplicate()
	out.c_declared_generation = _c_declared_generation.duplicate()
	out.declared_slots = _declared_slots.duplicate()
	out.declared_count = _declared_count
	out.last_hour_tick = _last_hour_tick
	_last_column_refusal = REFUSE_NONE
	return true


func restore_stock_age_columns(columns: CanonicalColumns) -> bool:
	"""Install a validated record's declarations and latch into this live stage.

	Same gate order from the other side: input null/shape, binding, busy, input scalar domains,
	input rows and dense list. NOTHING is written until every check has passed, so a refusal
	leaves the live columns, the latch, both calendar/math scratch objects, the two store/
	temperature factors, the borrowed collaborators and `_last_refusal` byte-identical.

	The four installed arrays are INDEPENDENT duplicates, so a caller that keeps and later edits
	its record cannot reach inside this store. The two scalars are copied exactly.

	EXACTLY TWO CACHES ARE RESET: `_spoiled_food_id` and `_compost_id` return to -1 so the
	ordinary `_preflight()` re-resolves them by key against whatever catalog is bound now. No
	other scratch is cleared, and `clear()` is deliberately not called -- it would drop the very
	declarations being restored and reset the latch.
	"""
	if columns == null or not _columns_shape_ok(columns):
		return _refuse_column(COLUMN_STOCK_AGE_SHAPE)
	if not _column_binding_ready():
		return _refuse_column(COLUMN_STOCK_AGE_BINDING)
	if _column_store_busy():
		return _refuse_column(COLUMN_STOCK_AGE_BUSY)
	if not _column_scalars_in_domain(columns.declared_count, columns.last_hour_tick):
		return _refuse_column(COLUMN_STOCK_AGE_RECORD)
	if not _column_payload_ok(columns.c_storage_class, columns.c_heated_interior,
			columns.c_declared_generation, columns.declared_slots, columns.declared_count):
		return _refuse_column(COLUMN_STOCK_AGE_RECORD)
	_c_storage_class = columns.c_storage_class.duplicate()
	_c_heated_interior = columns.c_heated_interior.duplicate()
	_c_declared_generation = columns.c_declared_generation.duplicate()
	_declared_slots = columns.declared_slots.duplicate()
	_declared_count = columns.declared_count
	_last_hour_tick = columns.last_hour_tick
	_spoiled_food_id = -1
	_compost_id = -1
	_last_column_refusal = REFUSE_NONE
	return true


func last_column_refusal() -> StringName:
	"""Reason the most recent column call refused, or REFUSE_NONE after one that succeeded."""
	return _last_column_refusal


func canonical_detail() -> String:
	"""The column refusal as text, for an adapter that carries a code and a detail string."""
	return String(last_column_refusal())


# --- private column helpers -----------------------------------------------------------------------

func _refuse_column(code: StringName) -> bool:
	"""Record a column refusal and answer false, having changed nothing else.

	`_last_refusal` is deliberately untouched: the operational diagnostic belongs to declaration
	and hour calls, and a save must not overwrite it.
	"""
	_last_column_refusal = code
	return false


func _column_binding_ready() -> bool:
	"""True when an Inventory is bound and a LOADED item catalog is bound beside it."""
	return _inventory != null and _definitions != null and _definitions.is_loaded()


func _column_store_busy() -> bool:
	"""True while the bound Inventory reports an open or poisoned transaction.

	Both are existing pure predicates over bool fields. This is a narrow busy test, not a
	quiescence proof for the world or for Inventory's journal.
	"""
	return _inventory.is_transaction_open() or _inventory.is_transaction_poisoned()


func _live_columns_shape_ok() -> bool:
	"""True when this store's own four columns are each at the compiled extent."""
	return _c_storage_class.size() == CONTAINER_CAPACITY \
		and _c_heated_interior.size() == CONTAINER_CAPACITY \
		and _c_declared_generation.size() == CONTAINER_CAPACITY \
		and _declared_slots.size() == CONTAINER_CAPACITY


static func _columns_shape_ok(columns: CanonicalColumns) -> bool:
	"""True when a record declares the compiled capacity and holds four columns of that size."""
	return columns.container_capacity == CONTAINER_CAPACITY \
		and columns.c_storage_class.size() == CONTAINER_CAPACITY \
		and columns.c_heated_interior.size() == CONTAINER_CAPACITY \
		and columns.c_declared_generation.size() == CONTAINER_CAPACITY \
		and columns.declared_slots.size() == CONTAINER_CAPACITY


static func _column_scalars_in_domain(count: int, latch: int) -> bool:
	"""Bound the two scalars in their NATIVE integer domains, before any narrowing happens.

	The count is `0..CONTAINER_CAPACITY` inclusive and the latch is `>= NO_HOUR_RUN`, matching
	the existing codec exactly: 751 is not newly rejected and no maximum tick is invented here.
	"""
	if count < 0 or count > CONTAINER_CAPACITY:
		return false
	return latch >= NO_HOUR_RUN


static func _column_payload_ok(storage_class: PackedByteArray, heated: PackedByteArray,
		generation: PackedInt32Array, slots: PackedInt32Array, count: int) -> bool:
	"""Every declaration row and the whole dense list, checked before any write anywhere.

	Rows, ascending: class in `0..STORAGE_CLASS_COUNT - 1`; heated 0 or 1; generation
	nonnegative. A DECLARED row (class above STORAGE_UNDECLARED) needs a POSITIVE generation --
	int32 storage already bounds it above -- and an UNDECLARED row must carry heated 0 and
	generation 0, which is exactly what `_drop_declaration()` leaves behind.

	List: the `[0, count)` prefix names in-range, DISTINCT, DECLARED rows, and the tail is all
	NULL_SLOT. `declared_rows == count` plus that distinctness is what proves every declared row
	occurs exactly once, without a second pass.

	The membership scratch is a FUNCTION-LOCAL byte array, released when this returns; it is
	never an owner field, and it is never indexed before the slot's range has been checked.
	Nothing here sorts, repairs or renumbers: the prefix ORDER is the hourly sweep order and is
	state, not presentation.
	"""
	var declared_rows: int = 0
	for slot: int in CONTAINER_CAPACITY:
		var kind: int = storage_class[slot]
		if kind >= STORAGE_CLASS_COUNT or heated[slot] > 1 or generation[slot] < 0:
			return false
		if kind == STORAGE_UNDECLARED:
			if heated[slot] != 0 or generation[slot] != 0:
				return false
			continue
		if generation[slot] <= 0:
			return false
		declared_rows += 1
	if declared_rows != count:
		return false
	var seen: PackedByteArray = PackedByteArray()
	seen.resize(CONTAINER_CAPACITY)
	seen.fill(0)
	for index: int in count:
		var slot: int = slots[index]
		if slot < 0 or slot >= CONTAINER_CAPACITY:
			return false
		if seen[slot] == 1 or storage_class[slot] == STORAGE_UNDECLARED:
			return false
		seen[slot] = 1
	for index: int in range(count, CONTAINER_CAPACITY):
		if slots[index] != NULL_SLOT:
			return false
	return true
