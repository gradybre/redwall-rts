extends RefCounted
## NEED-RATE-R01's selected-resident snapshot: one identity, one boundary, five rows.
##
## The ruling states the order and it is not negotiable, because every shortcut past it has a
## way of showing one resident's number under another's name: "The snapshot owner first
## validates the selected EntityRef/generation through the directory and resolves its RESIDENT
## typed row, THEN copies values and rates at one completed-state boundary. A global entity
## slot, persistent ID or cached stale typed row is not interchangeable ... All five rows use
## the same snapshot identity."
##
## `capture()` is that boundary. It takes the `(slot, generation)` reference the selection
## holds, runs `is_valid_of_kind(ref, KIND_RESIDENT)` -- which checks bounds, active, generation,
## kind, row range AND the reverse owner map -- resolves the typed row from the SAME validated
## reference, and then reads. A slot that has been reused by a different resident fails the
## generation check and the card refuses; it does not read the replacement.
##
## ---------------------------------------------------------------------------------------
## WHY THIS FILE CONTAINS NO RATE FORMULA. NEED-RATE-R01: "UI must not recreate those formulas,
## read private columns or substitute a universal baseline for missing data." The four signed
## net rates come from `needs.gd`'s own public readers:
##
##     rest_rate_milli_per_hour_into(slot, out)      comfort_rate_milli_per_hour_into(slot, out)
##     social_rate_milli_per_hour_into(slot, out)    purpose_rate_milli_per_hour_into(slot, out)
##
## Those four are SIGNED NET rates: "do not negate them again or subtract baseline a second
## time". Hunger is different and the ruling says so: `hunger_rate_milli_per_hour(size_class)`
## "remains a POSITIVE decay magnitude", so this adapter reads the verified size class, checks
## the result, and uses `R = -magnitude`. That asymmetry is the store's, not a guess.
##
## ---------------------------------------------------------------------------------------
## A REFUSAL IS NOT A ZERO. Every reader writes 0 into `out.value` when it refuses, so the
## refusal travels on `out.ok` alone. `_write_row()` therefore branches on the bool and writes
## `Rate unavailable` with the store's actual reason; it never prints the cleared zero, which
## would read as a balanced resident. `bound_rate_count()` says how many of the five bound, and
## UXV-020 passes only at five.
##
## ---------------------------------------------------------------------------------------
## SPEED IS ABSENT ON PURPOSE. "Pause and speeds 0/1/2/4 do not scale these per-simulated-hour
## rates." There is no speed or delta parameter to multiply by, at any level of this file.
##
## No allocation happens per capture: the five rows and the two IntResult readers are built
## once in `_init()`, and `capture()` writes through them.

const IntMath := preload("res://scripts/core/int_math.gd")
const NeedsScript := preload("res://scripts/core/needs.gd")
const ResidentsScript := preload("res://scripts/core/residents.gd")
const EntityDirectoryScript := preload("res://scripts/core/entity_directory.gd")
const UiNeedRate := preload("res://scripts/ui/ui_need_rate.gd")
const UiResidentCard := preload("res://scripts/ui/ui_resident_card.gd")

const REFUSE_NONE: StringName = &""
const REFUSE_NO_STORES: StringName = &"UI_SNAPSHOT_NO_STORES"
const REFUSE_STALE_SELECTION: StringName = &"UI_SNAPSHOT_STALE_SELECTION"
const REFUSE_NOT_A_RESIDENT: StringName = &"UI_SNAPSHOT_NOT_A_RESIDENT"
const REFUSE_ROW_NOT_LIVING: StringName = &"UI_SNAPSHOT_ROW_NOT_LIVING"
const REFUSE_NEED_OUT_OF_RANGE: StringName = &"UI_SNAPSHOT_NEED_OUT_OF_RANGE"


class NeedRow:
	"""One need row copied at the snapshot boundary: its value, its rate and its strings."""

	var label: String = ""
	## The store's own 0..10000 value. Never printed as a number; the track and percent use it.
	var basis_points: int = 0
	## The signed net rate R in milli-need-points per SIMULATED hour, as the store published it.
	var rate_milli: int = 0
	var has_rate: bool = false
	var capped: bool = false
	var value_text: String = ""
	var rate_text: String = ""
	var accessible: String = ""

	func clear() -> void:
		"""Empty this row so a refused capture leaves no previous resident's number behind."""
		label = ""
		basis_points = 0
		rate_milli = 0
		has_rate = false
		capped = false
		value_text = ""
		rate_text = ""
		accessible = ""


var _rows: Array[NeedRow] = []
## The reference every filled row belongs to. One identity for all five, by construction.
var _ref: Vector2i = EntityDirectoryScript.NULL_REF
var _row_index: int = -1
var _last_refusal: StringName = REFUSE_NONE
## Reused readers, so a capture allocates nothing.
var _value: IntMath.IntResult = IntMath.IntResult.new()
var _rate: IntMath.IntResult = IntMath.IntResult.new()


func _init() -> void:
	"""Build the five rows once. Nothing here allocates again."""
	for index: int in NeedsScript.NEED_COUNT:
		_rows.append(NeedRow.new())


func capture(directory: EntityDirectoryScript, residents: ResidentsScript, needs: NeedsScript,
		ref: Vector2i) -> bool:
	"""Validate the selection and copy all five rows from it at one completed-state boundary.

	Refuses by name and clears every row rather than returning a partly filled card. The typed
	row is resolved from the reference that was just validated, so no caller can hand in a slot
	the directory never agreed to.
	"""
	if directory == null or residents == null or needs == null:
		return _refuse(REFUSE_NO_STORES)
	if not directory.is_valid(ref):
		return _refuse(REFUSE_STALE_SELECTION)
	if not directory.is_valid_of_kind(ref, EntityDirectoryScript.KIND_RESIDENT):
		return _refuse(REFUSE_NOT_A_RESIDENT)
	var row: int = directory.get_typed_row(ref)
	if not residents.is_alive(row) or not needs.is_alive(row):
		return _refuse(REFUSE_ROW_NOT_LIVING)
	if not _read_values(needs, row):
		return _refuse(REFUSE_NEED_OUT_OF_RANGE)
	_fill_rates(needs, row)
	_ref = ref
	_row_index = row
	_last_refusal = REFUSE_NONE
	return true


func _read_values(needs: NeedsScript, row: int) -> bool:
	"""Copy all five need values first, and reject the WHOLE card if any is out of range.

	Checking every value before writing a single string is what stops the card printing four
	good rows and one impossible one: a value outside 0..10000 is a store invariant violation,
	not a display case.
	"""
	for need: int in NeedsScript.NEED_COUNT:
		if not needs.need_into(row, need, _value):
			return false
		if _value.value < NeedsScript.NEED_MIN or _value.value > NeedsScript.NEED_MAX:
			return false
		_rows[need].basis_points = _value.value
	return true


func _fill_rates(needs: NeedsScript, row: int) -> void:
	"""Ask the store for each need's published rate and write the five rows from the answers."""
	for need: int in NeedsScript.NEED_COUNT:
		var bound: bool = _read_rate(needs, row, need)
		_write_row(_rows[need], need, bound)


func _read_rate(needs: NeedsScript, row: int, need: int) -> bool:
	"""Put one need's signed rate in `_rate`, or refuse with the reason it could not be read.

	Five statically typed calls, one per GDD §4.2 need, each into the caller-owned `_rate`. No
	rate is computed here and none is derived from another: hunger has its own adapter because
	its published reader means the opposite sign, and the other four are taken as they come.
	"""
	match need:
		NeedsScript.NEED_HUNGER:
			return _read_hunger_rate(needs, row)
		NeedsScript.NEED_REST:
			return needs.rest_rate_milli_per_hour_into(row, _rate)
		NeedsScript.NEED_COMFORT:
			return needs.comfort_rate_milli_per_hour_into(row, _rate)
		NeedsScript.NEED_SOCIAL:
			return needs.social_rate_milli_per_hour_into(row, _rate)
		NeedsScript.NEED_PURPOSE:
			return needs.purpose_rate_milli_per_hour_into(row, _rate)
	return _rate.refuse("no published reader is declared for need %d" % need)


func _read_hunger_rate(needs: NeedsScript, row: int) -> bool:
	"""Hunger's rate: the published POSITIVE decay magnitude for the verified size, negated once.

	The ruling keeps `hunger_rate_milli_per_hour()`'s established sign and callers, so the
	adapter obtains the size class, checks the result, and uses `R = -magnitude`. The magnitude
	already carries the size and season multipliers; nothing is applied to it here.
	"""
	var size_class: IntMath.IntResult = needs.size_class_of(row)
	if not size_class.ok:
		return _rate.refuse(size_class.error)
	var magnitude: IntMath.IntResult = needs.hunger_rate_milli_per_hour(size_class.value)
	if not magnitude.ok:
		return _rate.refuse(magnitude.error)
	return _rate.succeed(-magnitude.value)


func _write_row(row: NeedRow, need: int, bound: bool) -> void:
	"""Format one row from its copied value and the rate the store did or did not publish."""
	row.label = UiResidentCard.NEED_LABELS[need]
	row.value_text = UiResidentCard.percent_text(row.basis_points)
	row.has_rate = bound
	row.rate_milli = _rate.value if bound else 0
	row.capped = bound and UiNeedRate.is_capped(row.basis_points, row.rate_milli)
	row.rate_text = UiNeedRate.row_text(row.basis_points, row.rate_milli) if bound \
		else UiNeedRate.UNAVAILABLE
	var detail: String = UiNeedRate.accessible_text(row.basis_points, row.rate_milli) if bound \
		else "%s: %s" % [UiNeedRate.UNAVAILABLE, _rate.error]
	row.accessible = "%s, field %s, %s, %s" \
		% [row.label, UiResidentCard.NEED_FIELDS[need], row.value_text, detail]


func row(need: int) -> NeedRow:
	"""One captured need row. Callers pass a `NeedsScript.NEED_*` index."""
	return _rows[need]


func row_count() -> int:
	"""How many rows the snapshot carries. GDD §4.2 fixes five."""
	return _rows.size()


func bound_rate_count() -> int:
	"""How many of the five rows carry a published rate. Five is UXV-020's passing condition."""
	var bound: int = 0
	for need: int in _rows.size():
		if _rows[need].has_rate:
			bound += 1
	return bound


func selected_ref() -> Vector2i:
	"""The reference every filled row belongs to, or the null reference after a refusal."""
	return _ref


func resident_row() -> int:
	"""The RESIDENT typed row this snapshot resolved, or -1 when it holds no capture."""
	return _row_index


func last_refusal() -> StringName:
	"""The code of the most recent refusal, or the empty StringName after a capture."""
	return _last_refusal


func _refuse(code: StringName) -> bool:
	"""Record a refusal, clear every row and forget the identity. Returns false."""
	_last_refusal = code
	_ref = EntityDirectoryScript.NULL_REF
	_row_index = -1
	for need: int in _rows.size():
		_rows[need].clear()
	return false
