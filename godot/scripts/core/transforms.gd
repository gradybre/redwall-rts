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
@warning_ignore("integer_division") const YAW_HALF_TURN: int = YAW_UNITS_PER_TURN / 2

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

## TRANSFORMS-S4-VALIDATE-R01 v1: the INACTIVE saved-image codes `columns_refusal()` returns.
## They judge a caller's packed columns only; no live path ever stores one in `_last_refusal`.
const REFUSE_COLUMN_SHAPE: StringName = &"COLUMN_SHAPE"
const REFUSE_COLUMN_BINDING_ID: StringName = &"COLUMN_BINDING_ID"
const REFUSE_COLUMN_BINDING_DUPLICATE: StringName = &"COLUMN_BINDING_DUPLICATE"
const REFUSE_COLUMN_FREE_ROW: StringName = &"COLUMN_FREE_ROW"

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
# Runtime cache freshness only; never saved, hashed or allowed to wrap into an old token.
var _mutation_revision: int = 1
## The code of the most recent refused bulk column call, or REFUSE_NONE. A diagnostic channel
## separate from every mutator's `_last_refusal`, never saved or hashed.
var _last_column_refusal: StringName = REFUSE_NONE


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


func is_bound_directory(candidate: EntityDirectory) -> bool:
	"""Prove the actual identity namespace; matching numeric entity pairs cannot prove this."""
	return candidate != null and candidate == _directory


func mutation_revision() -> int:
	"""A positive runtime token changes on every successful write; zero permanently poisons caches."""
	return _mutation_revision if _mutation_revision < IntMath.INT64_MAX else 0


func invalidate_runtime_caches() -> void:
	"""Invalidate observations before an owning in-place restore; no authoritative pose byte changes."""
	_mark_mutated()


func _mark_mutated() -> void:
	"""Saturate forever on exhaustion so reset/load cannot recycle a token or leave a partial reset."""
	if _mutation_revision < IntMath.INT64_MAX:
		_mutation_revision += 1


func reset() -> void:
	"""COLD, GUARDED RESET: zero all nine columns and the derived count. Never on a tick path.

	GUARDED means the settlement is the only caller: it runs inside `settlement_system.reset()`,
	alongside the directory and resident clears, so a pose can never outlive the entity that owns
	it. INIT-POSE-R01 §2.4 is the reason it zeroes `_bound_persistent_id` too -- a new-world reset
	restarts persistent ids at 1, so leftover binding bytes from a PREVIOUS world would match a
	DIFFERENT entity that happens to draw the same id, and `is_bound()` would hand back a dead
	world's coordinates. Within one world ids never repeat and this could be skipped; across two
	worlds it cannot.

	LOAD IS NOT THIS CALL FOLLOWED BY SPAWNING. A restore installs saved current AND previous
	fields through their owner; calling `place()` for a restored resident would overwrite the
	saved history with previous = current and silently flatten one tick of motion.

	Allocates nothing: every column is filled in place at the capacity `_init()` sized it to.
	"""
	_mark_mutated()
	_x.fill(0)
	_y.fill(0)
	_z.fill(0)
	_yaw.fill(0)
	_prev_x.fill(0)
	_prev_y.fill(0)
	_prev_z.fill(0)
	_prev_yaw.fill(0)
	_bound_persistent_id.fill(0)
	_bound_count = 0
	_last_refusal = REFUSE_NONE


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
	_mark_mutated()
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
	_mark_mutated()
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
	_mark_mutated()
	_prev_yaw[row] = _yaw[row]
	_yaw[row] = yaw
	_last_refusal = REFUSE_NONE
	return true


static func turn_stationary_preflighted(actual: RefCounted, ref: Vector2i,
		point: Vector3i, previous_yaw: int, revision: int, yaw: int) -> bool:
	"""Commit one proved stationary tick without dispatching a mutable Transform observer."""
	if actual == null or revision <= 0 or revision >= IntMath.INT64_MAX \
			or actual._mutation_revision != revision or yaw < 0 or yaw >= YAW_UNITS_PER_TURN:
		return false
	var row: int = _stationary_row(actual, ref)
	if row < 0 or actual._x[row] != point.x or actual._y[row] != point.y \
			or actual._z[row] != point.z or actual._yaw[row] != previous_yaw:
		return false
	actual._prev_x[row] = point.x
	actual._prev_y[row] = point.y
	actual._prev_z[row] = point.z
	actual._prev_yaw[row] = previous_yaw
	actual._yaw[row] = yaw
	actual._mutation_revision += 1
	actual._last_refusal = REFUSE_NONE
	return true


static func _stationary_row(actual: RefCounted, ref: Vector2i) -> int:
	"""Only a full live Resident and its current positive PID may receive the proved turn."""
	var ids: EntityDirectory = actual._directory
	if ids == null or ref.x < 0 or ref.x >= EntityDirectory.DIRECTORY_CAPACITY \
			or ids._active[ref.x] != 1 or ids._generation[ref.x] != ref.y \
			or ids._kind[ref.x] != EntityDirectory.KIND_RESIDENT:
		return -1
	var row: int = ids._typed_row[ref.x]
	if row < 0 or row >= EntityDirectory.KIND_CAPACITY[EntityDirectory.KIND_RESIDENT] \
			or ids._typed_owner_slot[ids._kind_base[EntityDirectory.KIND_RESIDENT] + row] != ref.x:
		return -1
	var position: int = POSITIONED_BASE[EntityDirectory.KIND_RESIDENT] + row
	return position if ids._persistent_id[ref.x] > 0 \
		and actual._bound_persistent_id[position] == ids._persistent_id[ref.x] else -1


func unbind(ref: Vector2i) -> bool:
	"""Release a placed row when its owner is retired, zeroing the pose and the binding stamp."""
	var row: int = _bound_row_of(ref)
	if row == NOT_POSITIONED:
		_last_refusal = _bound_refusal(ref)
		return false
	_mark_mutated()
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


func state_bytes() -> PackedByteArray:
	"""A deterministic image of all nine authoritative columns, for equality comparison.

	Decision 0059's refusal assertion: a refused placement must leave this store byte-identical,
	and no field-by-field inspection establishes that as convincingly -- a reader can forget a
	column, and this cannot. Not a save format: no header, no version, no declared widths.

	This ALLOCATES, deliberately and only here. It is a diagnostic and test path and is never
	called from a tick; `authoritative_digest()` is the non-copying scan for the same question.
	"""
	var image: PackedByteArray = PackedByteArray()
	image.append_array(_x.to_byte_array())
	image.append_array(_y.to_byte_array())
	image.append_array(_z.to_byte_array())
	image.append_array(_yaw.to_byte_array())
	image.append_array(_prev_x.to_byte_array())
	image.append_array(_prev_y.to_byte_array())
	image.append_array(_prev_z.to_byte_array())
	image.append_array(_prev_yaw.to_byte_array())
	image.append_array(_bound_persistent_id.to_byte_array())
	return image


func last_refusal() -> StringName:
	"""The refusal code from the most recent refusing call, or REFUSE_NONE after a success."""
	return _last_refusal


# --- saved-image column validation ------------------------------------------------------------

static func columns_refusal(bound_persistent_id: PackedInt32Array, x: PackedInt32Array,
		y: PackedInt32Array, z: PackedInt32Array, yaw: PackedInt32Array,
		prev_x: PackedInt32Array, prev_y: PackedInt32Array, prev_z: PackedInt32Array,
		prev_yaw: PackedInt32Array) -> StringName:
	"""Judge one INACTIVE owner 15 image's nine columns, in canonical STAMP-FIRST order.

	Pure and static: no store, no Directory, no live owner, no callback, no I/O, no repair, and
	no write to `_last_refusal` or any other diagnostic. Every gate completes over ALL rows
	before the next begins, so the first refusal is global and not merely the first faulty row.

	  1 COLUMN_SHAPE              any column that is not exactly TRANSFORM_CAPACITY long
	  2 COLUMN_BINDING_ID         any negative binding stamp
	  3 COLUMN_BINDING_DUPLICATE  a positive stamp repeated; repeated zeros are legal
	  4 COLUMN_FREE_ROW           a zero-bound row whose eight pose values are not all zero

	All eight pose fields keep the FULL signed int32 domain at a positively bound row: no map,
	yaw normalisation, speed or current/previous equality rule is applied, and current and
	previous stay independent canonical history. A positive stamp naming a destroyed entity is
	legitimate stale history and is accepted; the saved Directory cursor and same-file identity
	belong to TRANSFORMS-SAVED-IDENTITY. An all-zero image is a valid empty Transform image.

	`state_bytes()` is an existing diagnostic whose stamp comes LAST; its order is unchanged and
	a fixture built from it must be remapped explicitly into this canonical argument order.
	"""
	if bound_persistent_id.size() != TRANSFORM_CAPACITY or x.size() != TRANSFORM_CAPACITY \
			or y.size() != TRANSFORM_CAPACITY or z.size() != TRANSFORM_CAPACITY \
			or yaw.size() != TRANSFORM_CAPACITY or prev_x.size() != TRANSFORM_CAPACITY \
			or prev_y.size() != TRANSFORM_CAPACITY or prev_z.size() != TRANSFORM_CAPACITY \
			or prev_yaw.size() != TRANSFORM_CAPACITY:
		return REFUSE_COLUMN_SHAPE
	for row: int in TRANSFORM_CAPACITY:
		if bound_persistent_id[row] < 0:
			return REFUSE_COLUMN_BINDING_ID
	if _has_duplicate_positive_binding(bound_persistent_id):
		return REFUSE_COLUMN_BINDING_DUPLICATE
	for row: int in TRANSFORM_CAPACITY:
		if bound_persistent_id[row] != 0:
			continue
		if x[row] != 0 or y[row] != 0 or z[row] != 0 or yaw[row] != 0 \
				or prev_x[row] != 0 or prev_y[row] != 0 or prev_z[row] != 0 \
				or prev_yaw[row] != 0:
			return REFUSE_COLUMN_FREE_ROW
	return REFUSE_NONE


static func _has_duplicate_positive_binding(bound_persistent_id: PackedInt32Array) -> bool:
	"""True when any POSITIVE stamp appears twice. Repeated zeros are legal free rows.

	The ONE scratch allocation this validation makes: a single 87552-element copy, 350208 bytes,
	sorted privately so the caller's column is never reordered and the copy is never retained.
	Negative stamps are already refused by the earlier global gate.
	"""
	var sorted: PackedInt32Array = bound_persistent_id.duplicate()
	sorted.sort()
	for index: int in TRANSFORM_CAPACITY - 1:
		var value: int = sorted[index]
		if value > 0 and value == sorted[index + 1]:
			return true
	return false


# --- ARCH-SAVE-002 section 4 bulk column API (ADR 1222 build step 2) ----------------------------
#
# Owner 15's capture and apply steps, mirroring `priorities.gd`'s pair. `copy_columns_into()` is
# an exact snapshot of the nine authoritative columns over ALL 87552 physical rows, free rows
# included; `restore_columns()` judges a candidate with the SAME `columns_refusal()` the offline
# bridge uses, writes nothing on refusal, then installs the nine columns and REBUILDS
# `_bound_count` (the derived count) from the installed stamp column. No member belongs to
# another section: this store holds no Directory state. `_last_column_refusal` is the only other
# member either call writes. Saved binding IDs are carried exactly: their cross-owner identity
# agreement with the saved Directory is a later whole-world step, not this owner's.

class Columns:
	"""Caller-owned image of the nine authoritative columns, in canonical stamp-first order.

	One object per save or load, never per resident (ARCH-MEM-001). `copy_columns_into()` refills
	the buffers in place and refuses a wrongly sized one rather than resizing it.
	"""
	var bound_persistent_id: PackedInt32Array = PackedInt32Array()
	var x: PackedInt32Array = PackedInt32Array()
	var y: PackedInt32Array = PackedInt32Array()
	var z: PackedInt32Array = PackedInt32Array()
	var yaw: PackedInt32Array = PackedInt32Array()
	var prev_x: PackedInt32Array = PackedInt32Array()
	var prev_y: PackedInt32Array = PackedInt32Array()
	var prev_z: PackedInt32Array = PackedInt32Array()
	var prev_yaw: PackedInt32Array = PackedInt32Array()

	func _init() -> void:
		"""Size all nine columns to their declared extent, then fill the empty-store image."""
		bound_persistent_id.resize(TRANSFORM_CAPACITY)
		x.resize(TRANSFORM_CAPACITY)
		y.resize(TRANSFORM_CAPACITY)
		z.resize(TRANSFORM_CAPACITY)
		yaw.resize(TRANSFORM_CAPACITY)
		prev_x.resize(TRANSFORM_CAPACITY)
		prev_y.resize(TRANSFORM_CAPACITY)
		prev_z.resize(TRANSFORM_CAPACITY)
		prev_yaw.resize(TRANSFORM_CAPACITY)
		clear()

	func clear() -> void:
		"""Refill every column with what the store's own `reset()` leaves: all zero."""
		bound_persistent_id.fill(0)
		x.fill(0)
		y.fill(0)
		z.fill(0)
		yaw.fill(0)
		prev_x.fill(0)
		prev_y.fill(0)
		prev_z.fill(0)
		prev_yaw.fill(0)

	func equals(other: Columns) -> bool:
		"""True when all nine columns are byte-identical. Proves a refusal changed nothing."""
		return other != null and bound_persistent_id == other.bound_persistent_id \
			and x == other.x and y == other.y and z == other.z and yaw == other.yaw \
			and prev_x == other.prev_x and prev_y == other.prev_y and prev_z == other.prev_z \
			and prev_yaw == other.prev_yaw


func last_column_refusal() -> StringName:
	"""The code of the most recent refused bulk column call, or REFUSE_NONE after a success.

	A SEPARATE channel from `last_refusal()`, so a load can never overwrite the reason a
	per-entity write was refused before its caller read it. Every code is `COLUMN_`.
	"""
	return _last_column_refusal


func copy_columns_into(out: Columns) -> bool:
	"""Copy the nine authoritative columns into caller-owned buffers. False refuses; `out` unchanged.

	The ONLY reader of a free row's bytes through the bulk path. The copies are snapshots:
	mutating `out` afterwards cannot reach a column, and a later write here cannot reach `out`.
	"""
	if not _columns_are_capacity_sized(out):
		_last_column_refusal = REFUSE_COLUMN_SHAPE
		return false
	_refill_i32(out.bound_persistent_id, _bound_persistent_id)
	_refill_i32(out.x, _x)
	_refill_i32(out.y, _y)
	_refill_i32(out.z, _z)
	_refill_i32(out.yaw, _yaw)
	_refill_i32(out.prev_x, _prev_x)
	_refill_i32(out.prev_y, _prev_y)
	_refill_i32(out.prev_z, _prev_z)
	_refill_i32(out.prev_yaw, _prev_yaw)
	_last_column_refusal = REFUSE_NONE
	return true


func restore_columns(columns: Columns) -> bool:
	"""Replace all nine columns and rebuild `_bound_count`. False refuses; nothing is written.

	Allocate before consume (decision 0059): the null guard and the whole `columns_refusal()` run
	before the first write, so a refusal leaves every column and the derived count byte-identical.
	The rebuild counts the INSTALLED stamp column's positive entries, never a caller value. No
	cross-owner binding agreement with a saved Directory is checked here; the orchestrator's
	whole-world check owns that -- saved binding IDs are carried exactly.
	"""
	var refusal: StringName = REFUSE_COLUMN_SHAPE
	if _columns_are_capacity_sized(columns):
		refusal = columns_refusal(columns.bound_persistent_id, columns.x, columns.y, columns.z,
			columns.yaw, columns.prev_x, columns.prev_y, columns.prev_z, columns.prev_yaw)
	if refusal != REFUSE_NONE:
		_last_column_refusal = refusal
		return false
	_mark_mutated()
	_bound_persistent_id = columns.bound_persistent_id.duplicate()
	_x = columns.x.duplicate()
	_y = columns.y.duplicate()
	_z = columns.z.duplicate()
	_yaw = columns.yaw.duplicate()
	_prev_x = columns.prev_x.duplicate()
	_prev_y = columns.prev_y.duplicate()
	_prev_z = columns.prev_z.duplicate()
	_prev_yaw = columns.prev_yaw.duplicate()
	_bound_count = _count_nonzero(_bound_persistent_id)
	_last_column_refusal = REFUSE_NONE
	return true


static func _columns_are_capacity_sized(columns: Columns) -> bool:
	"""The shared null and extent guard of both bulk calls, before any indexed read."""
	return columns != null and columns.bound_persistent_id.size() == TRANSFORM_CAPACITY \
		and columns.x.size() == TRANSFORM_CAPACITY and columns.y.size() == TRANSFORM_CAPACITY \
		and columns.z.size() == TRANSFORM_CAPACITY and columns.yaw.size() == TRANSFORM_CAPACITY \
		and columns.prev_x.size() == TRANSFORM_CAPACITY \
		and columns.prev_y.size() == TRANSFORM_CAPACITY \
		and columns.prev_z.size() == TRANSFORM_CAPACITY \
		and columns.prev_yaw.size() == TRANSFORM_CAPACITY


static func _refill_i32(out: PackedInt32Array, source: PackedInt32Array) -> void:
	"""Refill a caller's int32 buffer in place with a snapshot of one column. One C++ copy."""
	out.clear()
	out.append_array(source)


static func _count_nonzero(bound_persistent_id: PackedInt32Array) -> int:
	"""How many rows the installed stamp column marks placed; the rebuilt `_bound_count`.

	Zero marks a free row and a validated column never carries a negative stamp, so this is an
	exact positive-stamp count.
	"""
	var count: int = 0
	for row: int in TRANSFORM_CAPACITY:
		if bound_persistent_id[row] != 0:
			count += 1
	return count
