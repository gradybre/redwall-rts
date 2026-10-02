extends RefCounted
## DEMO-CONTAIN-R01 step D4 (decision 0534): what the coordinator's *admit* wrote for each building.
##
## `settlement_system.gd::request_demolition()` is the only place Buildings, Construction and
## Inventory meet (decision 0145), so the admit step's two facts that belong to none of those
## stores live here, one row per Building typed row (BUILDING_CAPACITY = 1024):
##
##   * THE OUTPUT RESERVATION. Admit reserves Inventory headroom for the 50% return (blocker 3;
##     BUILD-C4-R01's "reserve legal output capacity before the final atomic refund/removal").
##     Inventory's `reserved_mass_g` is an anonymous per-container total, so the binding of that
##     claim to its demolition -- which container, how many grams, for which project -- is
##     recorded here, where D5's commit reads it to place the return and release the claim. A
##     null container with 0 g means the whole return falls back to ground piles (#9).
##   * THE DESTINATION REVISION. MOVE-DEP-R05 makes the contact owner publish a positive
##     `destination_revision` and INV-GOODS-R01 says it "advances on demolition/access edits
##     affecting admission". No building store published one, so the coordinator does, per
##     Building row: FIRST_DESTINATION_REVISION after `clear()`, +1 per admitted demolition, and
##     never reused for a row, so a reused row's new building never inherits an equal revision
##     under the same identity. Movement consuming it is D8.
##
## A RESERVATION OUTLIVES NOTHING SILENTLY. The record's project and binding readers answer only
## while the project is a live CONSTRUCTION row, but the reserved grams stay recorded until
## `release()` is called by whoever released them in Inventory (the coordinator's cancellation,
## or D5's commit). Until then `admit_refusal()` refuses RESERVATION_UNRELEASED and
## `unreleased_*_of()` still names the claim, so a project retired without its claim being
## released can neither hide the claim nor be admitted again over it. Nothing here touches
## another store.

const EntityDirectory := preload("res://scripts/core/entity_directory.gd")
const BuildingsScript := preload("res://scripts/core/buildings.gd")
const SpatialWorldScript := preload("res://scripts/core/spatial_world.gd")

const BUILDING_CAPACITY: int = BuildingsScript.BUILDING_CAPACITY
const FIRST_DESTINATION_REVISION: int = SpatialWorldScript.FIRST_DESTINATION_REVISION
const INT32_MAX: int = 2147483647
const NULL_REF: Vector2i = EntityDirectory.NULL_REF

const REFUSE_NONE: StringName = &""
const REFUSE_STALE_BUILDING: StringName = &"DEMOLITION_ADMISSION_STALE_BUILDING"
const REFUSE_ALREADY_ADMITTED: StringName = &"DEMOLITION_ALREADY_ADMITTED"
const REFUSE_REVISION_EXHAUSTED: StringName = &"DEMOLITION_DESTINATION_REVISION_EXHAUSTED"
const REFUSE_STALE_PROJECT: StringName = &"DEMOLITION_ADMISSION_STALE_PROJECT"
const REFUSE_OUTPUT_SHAPE: StringName = &"DEMOLITION_ADMISSION_OUTPUT_SHAPE"
const REFUSE_RESERVATION_UNRELEASED: StringName = &"DEMOLITION_RESERVATION_UNRELEASED"
const REFUSE_NOTHING_TO_RELEASE: StringName = &"DEMOLITION_ADMISSION_NOTHING_TO_RELEASE"

var _directory: EntityDirectory = null
var _project_slot: PackedInt32Array = PackedInt32Array()
var _project_generation: PackedInt32Array = PackedInt32Array()
var _output_slot: PackedInt32Array = PackedInt32Array()
var _output_generation: PackedInt32Array = PackedInt32Array()
var _destination_revision: PackedInt32Array = PackedInt32Array()
var _output_reserved_g: PackedInt64Array = PackedInt64Array()


func _init(directory: EntityDirectory) -> void:
	"""Bind the one directory every ref here validates against, and size the columns once."""
	_directory = directory
	_project_slot.resize(BUILDING_CAPACITY)
	_project_generation.resize(BUILDING_CAPACITY)
	_output_slot.resize(BUILDING_CAPACITY)
	_output_generation.resize(BUILDING_CAPACITY)
	_destination_revision.resize(BUILDING_CAPACITY)
	_output_reserved_g.resize(BUILDING_CAPACITY)
	clear()


func clear() -> void:
	"""Forget every admission and restart every revision at FIRST_DESTINATION_REVISION."""
	_project_slot.fill(NULL_REF.x)
	_project_generation.fill(NULL_REF.y)
	_output_slot.fill(NULL_REF.x)
	_output_generation.fill(NULL_REF.y)
	_destination_revision.fill(FIRST_DESTINATION_REVISION)
	_output_reserved_g.fill(0)


func _row_of(building_ref: Vector2i) -> int:
	"""The Building typed row a live building ref names, or -1."""
	if not _directory.is_valid_of_kind(building_ref, EntityDirectory.KIND_BUILDING):
		return -1
	return _directory.get_typed_row(building_ref)


func _live_project_row(row: int) -> bool:
	"""Whether this row's recorded project is still a live CONSTRUCTION row."""
	var project: Vector2i = Vector2i(_project_slot[row], _project_generation[row])
	return _directory.is_valid_of_kind(project, EntityDirectory.KIND_CONSTRUCTION)


func admit_refusal(building_ref: Vector2i) -> StringName:
	"""Why `record()` would refuse for this building right now, or REFUSE_NONE. Writes nothing."""
	var row: int = _row_of(building_ref)
	if row < 0:
		return REFUSE_STALE_BUILDING
	if _live_project_row(row):
		return REFUSE_ALREADY_ADMITTED
	if _output_reserved_g[row] > 0:
		return REFUSE_RESERVATION_UNRELEASED
	# Headroom for this admission AND its later release, so a cancellation never runs out.
	if _destination_revision[row] >= INT32_MAX - 1:
		return REFUSE_REVISION_EXHAUSTED
	return REFUSE_NONE


func record(building_ref: Vector2i, project_ref: Vector2i, output_ref: Vector2i,
		reserved_g: int) -> StringName:
	"""Record one admitted demolition and advance the building's destination revision.

	`output_ref` is the INVENTORY container holding the reservation, or the null ref with
	`reserved_g` 0 when the return falls back to ground piles; any other pairing refuses.
	Refuses, writing nothing, everything `admit_refusal()` names and a project that is not live.
	"""
	var code: StringName = admit_refusal(building_ref)
	if code != REFUSE_NONE:
		return code
	if not _directory.is_valid_of_kind(project_ref, EntityDirectory.KIND_CONSTRUCTION):
		return REFUSE_STALE_PROJECT
	if reserved_g < 0 or (output_ref == NULL_REF) != (reserved_g == 0):
		return REFUSE_OUTPUT_SHAPE
	var row: int = _row_of(building_ref)
	_project_slot[row] = project_ref.x
	_project_generation[row] = project_ref.y
	_output_slot[row] = output_ref.x
	_output_generation[row] = output_ref.y
	_output_reserved_g[row] = reserved_g
	_destination_revision[row] += 1
	return REFUSE_NONE


func release(building_ref: Vector2i) -> StringName:
	"""Forget a building's admission once its claim has been released in Inventory.

	The caller releases `unreleased_reserved_g_of()` grams from `unreleased_output_of()` FIRST;
	this only clears the record and advances the destination revision (the building's state
	changed under any admitted journey). Refuses a stale building and a row with no record.
	"""
	var code: StringName = release_refusal(building_ref)
	if code != REFUSE_NONE:
		return code
	var row: int = _row_of(building_ref)
	_project_slot[row] = NULL_REF.x
	_project_generation[row] = NULL_REF.y
	_output_slot[row] = NULL_REF.x
	_output_generation[row] = NULL_REF.y
	_output_reserved_g[row] = 0
	_destination_revision[row] += 1
	return REFUSE_NONE


func release_refusal(building_ref: Vector2i) -> StringName:
	"""Why `release()` would refuse right now, or REFUSE_NONE. Writes nothing."""
	var row: int = _row_of(building_ref)
	if row < 0:
		return REFUSE_STALE_BUILDING
	if _project_slot[row] == NULL_REF.x and _output_reserved_g[row] == 0:
		return REFUSE_NOTHING_TO_RELEASE
	if _destination_revision[row] >= INT32_MAX:
		return REFUSE_REVISION_EXHAUSTED
	return REFUSE_NONE


func unreleased_output_of(building_ref: Vector2i) -> Vector2i:
	"""The container still holding a recorded claim, live project or not; null when none."""
	var row: int = _row_of(building_ref)
	if row < 0 or _output_reserved_g[row] == 0:
		return NULL_REF
	return Vector2i(_output_slot[row], _output_generation[row])


func unreleased_reserved_g_of(building_ref: Vector2i) -> int:
	"""Grams of a recorded claim not yet released, live project or not; 0 when none."""
	var row: int = _row_of(building_ref)
	return 0 if row < 0 else _output_reserved_g[row]


func destination_revision_of(building_ref: Vector2i) -> int:
	"""The building contact's current destination revision, or 0 (no contact) for a stale ref."""
	var row: int = _row_of(building_ref)
	return 0 if row < 0 else _destination_revision[row]


func project_of(building_ref: Vector2i) -> Vector2i:
	"""The admitted demolition project of a building, or the null ref when none is live."""
	var row: int = _row_of(building_ref)
	if row < 0 or not _live_project_row(row):
		return NULL_REF
	return Vector2i(_project_slot[row], _project_generation[row])


func output_container_of(building_ref: Vector2i) -> Vector2i:
	"""The INVENTORY container holding the return's reservation, or the null ref."""
	if project_of(building_ref) == NULL_REF:
		return NULL_REF
	var row: int = _row_of(building_ref)
	return Vector2i(_output_slot[row], _output_generation[row])


func output_reserved_g_of(building_ref: Vector2i) -> int:
	"""Grams reserved for the return at admission; 0 with no live admission or a pile fallback."""
	if project_of(building_ref) == NULL_REF:
		return 0
	return _output_reserved_g[_row_of(building_ref)]


func state_bytes() -> PackedByteArray:
	"""Every column, for byte-identical refusal checks. Test use; allocates."""
	var out: PackedByteArray = PackedByteArray()
	out.append_array(var_to_bytes(_project_slot))
	out.append_array(var_to_bytes(_project_generation))
	out.append_array(var_to_bytes(_output_slot))
	out.append_array(var_to_bytes(_output_generation))
	out.append_array(var_to_bytes(_destination_revision))
	out.append_array(var_to_bytes(_output_reserved_g))
	return out
