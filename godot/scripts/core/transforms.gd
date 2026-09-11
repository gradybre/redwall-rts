extends RefCounted
## ARCH-SYS-001 Transform storage: the eight authoritative int32 fields of every positioned entity,
## current AND previous, in structure-of-arrays columns.
##
## ---------------------------------------------------------------------------------------
## THE ROW IS DERIVED, NOT ALLOCATED.
##
## systems_architecture.md 2.1 derives the positioned-entity capacity as
## `P = 512 + 1024 + 81920 + 4096 = 87552` -- exactly the residents, buildings, furniture and
## resource nodes of the directory. So a Transform row is not a second allocation handed out by a
## second allocator: it is `base(kind) + typed_row`, a pure function of the directory row the
## entity already owns. There is no free heap here, no slot-to-row map, and no way for an entity to
## hold two Transform rows or for two entities to share one.
##
## ---------------------------------------------------------------------------------------
## WHY ONE NEW COLUMN EXISTS, AND WHAT IT CATCHES.
##
## Deriving the row from `(kind, typed_row)` leaves one real hazard: a typed row is REUSED. Entity
## A occupies resident row 7, is destroyed, and entity B is created into resident row 7. B's
## reference is perfectly valid, `is_valid_of_kind()` passes, and the row still holds A's
## coordinates. Reading them would report a live position for an entity that has never been placed.
##
## `_bound_persistent_id[row]` closes that: it stores the OWNER'S PERSISTENT ID at the moment the
## row was placed, and every read requires it to equal the current owner's. Zero is never a live
## persistent ID, so zero means "never placed".
##
## IT IS THE PERSISTENT ID AND NOT THE GENERATION DELIBERATELY, and the difference is not academic.
## A generation belongs to a DIRECTORY SLOT, and two different slots routinely carry generation 1 --
## every slot's first use does. Directory slots and typed rows are allocated from separate free
## heaps, so an entity can inherit a typed row from a predecessor that lived in a DIFFERENT slot
## with the SAME generation, and a generation stamp would then read as a match and hand back the
## predecessor's coordinates. Persistent IDs are never reused at all, which is exactly the property
## needed here. 87552 int32 = 350208 bytes; decision 0053 records it in the ledger.
##
## ---------------------------------------------------------------------------------------
## PLACE VERSUS ADVANCE. `place()` writes previous = current, because a spawn or a teleport has no
## previous pose and interpolating across one would drag a body through solid geometry (crowd 12.1,
## SET-MOVE-001 6). `advance()` rolls current into previous and writes the new current, and is
## called AT MOST ONCE PER TICK PER ENTITY by the single mover -- `movement.gd`. Two `advance()`
## calls in one tick would lose the real tick-start pose, which is why there is exactly one mover.
##
## ---------------------------------------------------------------------------------------
## YAW: SCALE SETTLED, ZERO AND HANDEDNESS NOT. ARCH-AUTH-002 and GDD 4.2 fix yaw at 65536 units
## per turn, and that is all they fix. Which world direction yaw 0 faces, and which way positive
## yaw turns, is stated nowhere this slice may rely on. So NOTHING HERE DERIVES A YAW FROM A
## DIRECTION. Yaw is only ever what a caller supplies, `movement.gd` carries it through untouched,
## and the facing convention is named as a MOVE-G01/G04 blocker rather than guessed.

const IntMath := preload("res://scripts/core/int_math.gd")
const EntityDirectory := preload("res://scripts/core/entity_directory.gd")

## systems_architecture.md 2.1: "positioned-entity capacity P=512+1024+81920+4096=87552".
const TRANSFORM_CAPACITY: int = 87552

## ARCH-AUTH-002: "yaw is 65536 units/turn". The scale only; see the header on zero and handedness.
const YAW_UNITS_PER_TURN: int = 65536
const YAW_HALF_TURN: int = YAW_UNITS_PER_TURN / 2

## `base(kind)` for every directory kind, or NOT_POSITIONED. Ascending kind order, so the bases are
## the running sum of the four positioned capacities in `entity_directory.gd`'s KIND_CAPACITY.
const NOT_POSITIONED: int = -1
const POSITIONED_BASE: Array[int] = [
	0, NOT_POSITIONED, NOT_POSITIONED, NOT_POSITIONED, NOT_POSITIONED, NOT_POSITIONED,
	1024, NOT_POSITIONED, NOT_POSITIONED, NOT_POSITIONED, NOT_POSITIONED, NOT_POSITIONED,
	NOT_POSITIONED, NOT_POSITIONED, 82944, 83456, NOT_POSITIONED, NOT_POSITIONED,
]

const REFUSE_NONE: StringName = &""
const REFUSE_STALE_REF: StringName = &"TRANSFORM_REF_STALE"
const REFUSE_NOT_POSITIONED: StringName = &"KIND_HAS_NO_TRANSFORM"
const REFUSE_NOT_BOUND: StringName = &"TRANSFORM_NOT_PLACED"
const REFUSE_OUT_OF_INT32: StringName = &"TRANSFORM_FIELD_OUT_OF_INT32"
const REFUSE_INVALID_ALPHA: StringName = &"PRESENTATION_ALPHA_OUT_OF_RANGE"

## Digest modulus: a Mersenne prime, so the rolling product never leaves int64 and the digest is
## reproducible without relying on signed overflow behaviour.
const DIGEST_MODULUS: int = 2147483647
const DIGEST_MULTIPLIER: int = 131


class Pose:
	extends RefCounted
	## One entity's eight authoritative Transform fields. Caller-owned; `read_into()` fills it.

	var x: int = 0
	var y: int = 0
	var z: int = 0
	var yaw: int = 0
	var prev_x: int = 0
	var prev_y: int = 0
	var prev_z: int = 0
	var prev_yaw: int = 0

	func matches_previous() -> bool:
		"""True when current and previous agree -- a placed, teleported or stationary entity."""
		return x == prev_x and y == prev_y and z == prev_z and yaw == prev_yaw


class PresentationPose:
	extends RefCounted
	## THE ONLY FLOATS IN THE MOVEMENT SLICE, and they are drawing instructions, not state.
	##
	## `presentation_extract.gd` is the precedent: integers are the truth, a render frame between
	## two committed ticks asks for a pose at an alpha, and gets floats built from the two committed
	## integers either side of it. Nothing in the simulation reads these back, there is no setter
	## that reaches a column, and no gameplay outcome can depend on them. Positions are METRES --
	## crowd 12.1's "divide integer positions by 1024 only at extraction" -- and yaw stays in yaw
	## units because its zero reference is not this slice's to decide.

	var x_metres: float = 0.0
	var y_metres: float = 0.0
	var z_metres: float = 0.0
	var yaw_units: float = 0.0


var _directory: EntityDirectory = null

# --- the eight authoritative columns, systems_architecture.md 2.2 "Transform" --------------------

var _x: PackedInt32Array = PackedInt32Array()
var _y: PackedInt32Array = PackedInt32Array()
var _z: PackedInt32Array = PackedInt32Array()
var _yaw: PackedInt32Array = PackedInt32Array()
var _prev_x: PackedInt32Array = PackedInt32Array()
var _prev_y: PackedInt32Array = PackedInt32Array()
var _prev_z: PackedInt32Array = PackedInt32Array()
var _prev_yaw: PackedInt32Array = PackedInt32Array()

## This slice's one new column; see the header. Zero means "no live entity has placed this row".
var _bound_persistent_id: PackedInt32Array = PackedInt32Array()

var _bound_count: int = 0
var _last_refusal: StringName = REFUSE_NONE


func _init(directory: EntityDirectory) -> void:
	"""Bind the directory and allocate all nine columns once to the derived capacity P."""
	_directory = directory
	_x.resize(TRANSFORM_CAPACITY)
	_y.resize(TRANSFORM_CAPACITY)
	_z.resize(TRANSFORM_CAPACITY)
	_yaw.resize(TRANSFORM_CAPACITY)
	_prev_x.resize(TRANSFORM_CAPACITY)
	_prev_y.resize(TRANSFORM_CAPACITY)
	_prev_z.resize(TRANSFORM_CAPACITY)
	_prev_yaw.resize(TRANSFORM_CAPACITY)
	_bound_persistent_id.resize(TRANSFORM_CAPACITY)
	_assert_bases_tile_the_capacity()


func _assert_bases_tile_the_capacity() -> void:
	"""Fail loudly if the positioned bases and the directory capacities ever stop agreeing."""
	var total: int = 0
	for kind: int in EntityDirectory.KIND_COUNT:
		if POSITIONED_BASE[kind] == NOT_POSITIONED:
			continue
		assert(POSITIONED_BASE[kind] == total, "positioned bases must be the running capacity sum")
		total += EntityDirectory.KIND_CAPACITY[kind]
	assert(total == TRANSFORM_CAPACITY, "positioned kind capacities must sum to P")


# --- row derivation -------------------------------------------------------------------------------

static func kind_is_positioned(kind: int) -> bool:
	"""True when a directory kind owns Transform rows at all."""
	if kind < 0 or kind >= EntityDirectory.KIND_COUNT:
		return false
	return POSITIONED_BASE[kind] != NOT_POSITIONED


func transform_row_into(ref: Vector2i, out: IntMath.IntResult) -> bool:
	"""The derived Transform row of a live positioned entity, or an explicit refusal.

	Says nothing about whether the row has been PLACED; `is_bound()` answers that.
	"""
	if not _directory.is_valid(ref):
		_last_refusal = REFUSE_STALE_REF
		return out.refuse(REFUSE_STALE_REF)
	var kind: int = _directory.get_kind(ref)
	if not kind_is_positioned(kind):
		_last_refusal = REFUSE_NOT_POSITIONED
		return out.refuse(REFUSE_NOT_POSITIONED)
	_last_refusal = REFUSE_NONE
	return out.succeed(POSITIONED_BASE[kind] + _directory.get_typed_row(ref))


func _row_of(ref: Vector2i) -> int:
	"""The derived row of a live positioned entity, or NOT_POSITIONED. Internal absence only."""
	if not _directory.is_valid(ref):
		return NOT_POSITIONED
	var kind: int = _directory.get_kind(ref)
	if not kind_is_positioned(kind):
		return NOT_POSITIONED
	return POSITIONED_BASE[kind] + _directory.get_typed_row(ref)


func _bound_row_of(ref: Vector2i) -> int:
	"""The row of a live positioned entity that THIS entity has placed, or NOT_POSITIONED."""
	var row: int = _row_of(ref)
	if row == NOT_POSITIONED:
		return NOT_POSITIONED
	if _bound_persistent_id[row] != _directory.get_persistent_id(ref):
		return NOT_POSITIONED
	return row


func is_bound(ref: Vector2i) -> bool:
	"""True when this exact entity -- not merely this slot or this typed row -- has a placed pose."""
	return _bound_row_of(ref) != NOT_POSITIONED


func bound_count() -> int:
	"""How many Transform rows currently hold a placed pose."""
	return _bound_count


# --- writes ----------------------------------------------------------------------------------------

func place(ref: Vector2i, x: int, y: int, z: int, yaw: int) -> bool:
	"""Put an entity at a pose with NO history: previous = current, so nothing interpolates into it.

	This is spawn and teleport. Task 05.2's "Initialize previous=current" is exactly this call.
	"""
	var row: int = _row_of(ref)
	if row == NOT_POSITIONED:
		_last_refusal = _row_refusal(ref)
		return false
	if not _fields_fit_int32(x, y, z, yaw):
		_last_refusal = REFUSE_OUT_OF_INT32
		return false
	if _bound_persistent_id[row] == 0:
		_bound_count += 1
	_bound_persistent_id[row] = _directory.get_persistent_id(ref)
	_x[row] = x
	_y[row] = y
	_z[row] = z
	_yaw[row] = yaw
	_prev_x[row] = x
	_prev_y[row] = y
	_prev_z[row] = z
	_prev_yaw[row] = yaw
	_last_refusal = REFUSE_NONE
	return true


func advance(ref: Vector2i, x: int, y: int, z: int) -> bool:
	"""Roll the committed pose into `previous` and write a new current position. Yaw is untouched.

	Yaw is deliberately not a parameter: see the header. A caller that knows the facing convention
	uses `set_yaw()`; `movement.gd` does not, and must not invent one.
	"""
	var row: int = _bound_row_of(ref)
	if row == NOT_POSITIONED:
		_last_refusal = _bound_refusal(ref)
		return false
	if not _fields_fit_int32(x, y, z, _yaw[row]):
		_last_refusal = REFUSE_OUT_OF_INT32
		return false
	_prev_x[row] = _x[row]
	_prev_y[row] = _y[row]
	_prev_z[row] = _z[row]
	_prev_yaw[row] = _yaw[row]
	_x[row] = x
	_y[row] = y
	_z[row] = z
	_last_refusal = REFUSE_NONE
	return true


func set_yaw(ref: Vector2i, yaw: int) -> bool:
	"""Set a placed entity's facing, rolling the old yaw into `prev_yaw`, or refuse explicitly."""
	var row: int = _bound_row_of(ref)
	if row == NOT_POSITIONED:
		_last_refusal = _bound_refusal(ref)
		return false
	if not IntMath.fits_int32(yaw):
		_last_refusal = REFUSE_OUT_OF_INT32
		return false
	_prev_yaw[row] = _yaw[row]
	_yaw[row] = yaw
	_last_refusal = REFUSE_NONE
	return true


func unbind(ref: Vector2i) -> bool:
	"""Release a placed row when its owner is retired, zeroing the pose and the binding stamp."""
	var row: int = _bound_row_of(ref)
	if row == NOT_POSITIONED:
		_last_refusal = _bound_refusal(ref)
		return false
	_x[row] = 0
	_y[row] = 0
	_z[row] = 0
	_yaw[row] = 0
	_prev_x[row] = 0
	_prev_y[row] = 0
	_prev_z[row] = 0
	_prev_yaw[row] = 0
	_bound_persistent_id[row] = 0
	_bound_count -= 1
	_last_refusal = REFUSE_NONE
	return true


static func _fields_fit_int32(x: int, y: int, z: int, yaw: int) -> bool:
	"""True when all four pose fields fit the int32 columns they are about to be stored in."""
	return IntMath.fits_int32(x) and IntMath.fits_int32(y) \
		and IntMath.fits_int32(z) and IntMath.fits_int32(yaw)


func _row_refusal(ref: Vector2i) -> StringName:
	"""Which refusal a failed row derivation earned: a dead reference or an unpositioned kind."""
	if not _directory.is_valid(ref):
		return REFUSE_STALE_REF
	return REFUSE_NOT_POSITIONED


func _bound_refusal(ref: Vector2i) -> StringName:
	"""Which refusal a failed bound-row lookup earned, distinguishing stale from never placed."""
	if _row_of(ref) == NOT_POSITIONED:
		return _row_refusal(ref)
	return REFUSE_NOT_BOUND


# --- reads -----------------------------------------------------------------------------------------

func read_into(ref: Vector2i, out: Pose) -> bool:
	"""Copy a placed entity's eight authoritative fields into a caller-owned record."""
	var row: int = _bound_row_of(ref)
	if row == NOT_POSITIONED:
		_last_refusal = _bound_refusal(ref)
		return false
	out.x = _x[row]
	out.y = _y[row]
	out.z = _z[row]
	out.yaw = _yaw[row]
	out.prev_x = _prev_x[row]
	out.prev_y = _prev_y[row]
	out.prev_z = _prev_z[row]
	out.prev_yaw = _prev_yaw[row]
	_last_refusal = REFUSE_NONE
	return true


# --- the presentation boundary ----------------------------------------------------------------------

func presentation_interpolate_into(
	ref: Vector2i, alpha_numerator: int, alpha_denominator: int, out: PresentationPose
) -> bool:
	"""Fill `out` with the drawn pose between the previous and current committed ticks.

	The alpha arrives as an INTEGER FRACTION so a caller cannot smuggle a float into the argument
	list of an authoritative-looking call. Nothing this returns is read back by the simulation; see
	PresentationPose. Calling or not calling this cannot change one authoritative field, which is
	what the invisible-view independence acceptance item checks.
	"""
	var row: int = _bound_row_of(ref)
	if row == NOT_POSITIONED:
		_last_refusal = _bound_refusal(ref)
		return false
	if alpha_denominator <= 0 or alpha_numerator < 0 or alpha_numerator > alpha_denominator:
		_last_refusal = REFUSE_INVALID_ALPHA
		return false
	var alpha: float = float(alpha_numerator) / float(alpha_denominator)
	out.x_metres = _interpolate_metres(_prev_x[row], _x[row], alpha)
	out.y_metres = _interpolate_metres(_prev_y[row], _y[row], alpha)
	out.z_metres = _interpolate_metres(_prev_z[row], _z[row], alpha)
	out.yaw_units = _interpolate_yaw(_prev_yaw[row], _yaw[row], alpha)
	_last_refusal = REFUSE_NONE
	return true


static func _interpolate_metres(previous: int, current: int, alpha: float) -> float:
	"""Blend two committed 1/1024 m integers and convert to metres at the extraction boundary."""
	return (float(previous) + (float(current) - float(previous)) * alpha) / 1024.0


static func shortest_yaw_delta(previous: int, current: int) -> int:
	"""The signed shortest-arc difference between two yaws, in `(-32768, 32768]` yaw units."""
	var delta: int = (current - previous) % YAW_UNITS_PER_TURN
	if delta > YAW_HALF_TURN:
		delta -= YAW_UNITS_PER_TURN
	elif delta <= -YAW_HALF_TURN:
		delta += YAW_UNITS_PER_TURN
	return delta


static func _interpolate_yaw(previous: int, current: int, alpha: float) -> float:
	"""Shortest-arc yaw blend, so a turn past the 65536 wrap does not spin the long way round."""
	return float(previous) + float(shortest_yaw_delta(previous, current)) * alpha


# --- verification -----------------------------------------------------------------------------------

func authoritative_digest() -> int:
	"""A reproducible digest of every placed row's nine columns, for parity and equivalence checks.

	NOT a per-tick call: it scans all 87552 rows. It exists so a test can prove that two runs -- at
	different game speeds, with and without a presentation reader attached -- committed identical
	authoritative state, rather than comparing a handful of fields and hoping.
	"""
	var digest: int = 0
	for row: int in TRANSFORM_CAPACITY:
		if _bound_persistent_id[row] == 0:
			continue
		digest = _fold(digest, row)
		digest = _fold(digest, _bound_persistent_id[row])
		digest = _fold(_fold(_fold(_fold(digest, _x[row]), _y[row]), _z[row]), _yaw[row])
		digest = _fold(_fold(_fold(digest, _prev_x[row]), _prev_y[row]), _prev_z[row])
		digest = _fold(digest, _prev_yaw[row])
	return digest


static func _fold(digest: int, value: int) -> int:
	"""One digest step, kept inside int64 by construction rather than by signed overflow.

	`value` is reduced first, so even int32's most negative value cannot push the sum below zero
	and produce a platform-dependent modulo.
	"""
	return (digest * DIGEST_MULTIPLIER + value % DIGEST_MODULUS + DIGEST_MODULUS) % DIGEST_MODULUS


func last_refusal() -> StringName:
	"""The refusal code from the most recent refusing call, or REFUSE_NONE after a success."""
	return _last_refusal
