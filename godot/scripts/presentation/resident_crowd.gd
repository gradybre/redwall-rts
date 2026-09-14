extends MultiMeshInstance3D
## REQ-SET-163's CROWD TIER: every living resident drawn as one instance of ONE `MultiMesh`, with
## no node, no physics body, no navigation agent and no `AnimationTree` per resident.
##
## REQ-SET-163 allows "at most 24 of the 256 residents" to be conventional skeletal actors. This
## file is the OTHER path -- the one every resident uses until that tier exists -- and it is a
## single draw call over one preallocated instance buffer. The 24-actor tier is NOT built here and
## nothing below reserves, excludes or anticipates a slot for it.
##
## ---------------------------------------------------------------------------------------
## THIS OBJECT IS DOWNSTREAM OF THE SIMULATION AND CANNOT REACH BACK INTO IT.
##
## UNDER INIT-POSE-R01 BOTH READERS ARE THE SETTLEMENT'S OWN. `bind_stores()` always took the
## Transform store as an argument; what changed is that the argument is now
## `settlement_system.gd`'s single directory-bound instance rather than a presentation-private
## scaffold. Nothing in this file needed to change for that, and nothing here may construct one.
##
##   * IT HOLDS TWO BORROWED READERS AND CALLS ONLY CONST-SHAPED METHODS ON THEM.
##     `residents.is_alive()`, `residents.ref_of()` and `transforms.presentation_interpolate_into()`
##     are the complete list. None of the three writes an authoritative column; the third is
##     `transforms.gd`'s own float boundary, which fills a caller-owned record and whose docstring
##     states that "calling or not calling this cannot change one authoritative field".
##   * IT NEVER WRITES A POSE. There is no call to `place()`, `advance()`, `set_yaw()` or
##     `unbind()` anywhere in this file, and the pose record it reads into is private scratch.
##     A frame that is never drawn and a frame drawn a thousand times leave identical state.
##   * THE ALPHA ARRIVES AS AN INTEGER FRACTION, `numerator/denominator`, exactly as
##     `transforms.gd` demands, so no `float` enters an authoritative-looking argument list and
##     no sub-tick fraction can be stored back anywhere.
##
## ---------------------------------------------------------------------------------------
## ALLOCATED ONCE (ARCH-MEM-001). `_init()` sizes the instance buffer and the instance->slot
## column to `Residents.RESIDENT_CAPACITY` and NOTHING resizes them afterwards. A refresh writes
## three floats per drawn resident into a buffer that already exists, sets
## `visible_instance_count`, and allocates nothing at all. `MultiMesh.instance_count` is written
## exactly once, in `_build_multimesh()`; changing it at runtime reallocates the server-side
## buffer, which is why the live count is expressed through `visible_instance_count` instead.
##
## ---------------------------------------------------------------------------------------
## WHY 512 INSTANCES AND NOT 256. GDD 4.1 caps LIVING residents at 256, but `residents.gd` holds
## 512 ROWS -- `population()` counts rows including the dead, and a dead row keeps its slot until
## it is despawned. The buffer is sized on the row capacity so that a slot can always address an
## instance; `visible_instance_count` is what follows the living.
##
## ---------------------------------------------------------------------------------------
## FACING IS NOT APPLIED, AND THAT IS A NAMED BLOCKER, NOT AN OVERSIGHT. `transforms.gd`'s header
## states that ARCH-AUTH-002 fixes the yaw SCALE at 65536 units per turn and fixes nothing else:
## "Which world direction yaw 0 faces, and which way positive yaw turns, is stated nowhere this
## slice may rely on", and it names that as a MOVE-G01/G04 blocker. Turning a yaw integer into a
## basis requires exactly the two facts that are missing. So every instance keeps the identity
## basis and the interpolated yaw this object reads is deliberately discarded. When MOVE-G01/G04
## settle the convention, `_write_instance()` is the one place that changes.

const IntMath := preload("res://scripts/core/int_math.gd")
const ResidentsScript := preload("res://scripts/core/residents.gd")
const TransformsScript := preload("res://scripts/core/transforms.gd")

## One instance per resident ROW, not per living resident. See the header.
const INSTANCE_CAPACITY: int = ResidentsScript.RESIDENT_CAPACITY

## `MultiMesh.buffer` stores a TRANSFORM_3D instance as three rows of four floats: the three basis
## columns then the origin component, per row. Twelve floats, no colour and no custom data.
const FLOATS_PER_INSTANCE: int = 12
const OFFSET_ORIGIN_X: int = 3
const OFFSET_ORIGIN_Y: int = 7
const OFFSET_ORIGIN_Z: int = 11

## No resident occupies this instance. Distinct from slot 0, which is a real resident row.
const NO_SLOT: int = -1

const REFUSE_NONE: StringName = &""
const REFUSE_NOT_BOUND: StringName = &"CROWD_STORES_NOT_BOUND"
const REFUSE_INVALID_ALPHA: StringName = &"CROWD_ALPHA_OUT_OF_RANGE"
const REFUSE_INVALID_INSTANCE: StringName = &"CROWD_INVALID_INSTANCE"
const REFUSE_NO_MESH: StringName = &"CROWD_MESH_NOT_SET"

# --- borrowed readers: never written through, never published --------------------------------

var _residents: ResidentsScript = null
var _transforms: TransformsScript = null

# --- the preallocated instance buffer (ARCH-MEM-001) ------------------------------------------

var _buffer: PackedFloat32Array = PackedFloat32Array()
var _instance_slot: PackedInt32Array = PackedInt32Array()

var _drawn_count: int = 0
var _skipped_unplaced: int = 0
var _last_refusal: StringName = REFUSE_NONE

# --- scratch: caller-owned records reused every frame, allocated here and nowhere else --------

var _pose: TransformsScript.PresentationPose = TransformsScript.PresentationPose.new()


func _init() -> void:
	"""Size both columns and the MultiMesh once, before this node can ever be drawn."""
	_buffer.resize(INSTANCE_CAPACITY * FLOATS_PER_INSTANCE)
	_instance_slot.resize(INSTANCE_CAPACITY)
	_reset_buffer()
	_build_multimesh()


func _build_multimesh() -> void:
	"""Create the one MultiMesh this node ever owns. `instance_count` is written exactly once."""
	var mesh_data: MultiMesh = MultiMesh.new()
	mesh_data.transform_format = MultiMesh.TRANSFORM_3D
	mesh_data.use_colors = false
	mesh_data.use_custom_data = false
	mesh_data.instance_count = INSTANCE_CAPACITY
	mesh_data.visible_instance_count = 0
	multimesh = mesh_data


func _reset_buffer() -> void:
	"""Write an identity basis into every instance and park every origin at the world origin.

	Only the three origin floats are touched per frame afterwards, so the basis is established
	here once. `_instance_slot` is cleared with it: an instance nobody draws names no resident.
	"""
	_buffer.fill(0.0)
	for instance: int in INSTANCE_CAPACITY:
		var base: int = instance * FLOATS_PER_INSTANCE
		_buffer[base + 0] = 1.0
		_buffer[base + 5] = 1.0
		_buffer[base + 10] = 1.0
		_instance_slot[instance] = NO_SLOT
	_drawn_count = 0


func bind_stores(residents: ResidentsScript, transforms: TransformsScript) -> bool:
	"""Adopt the two READERS this crowd draws from. Refuses either being absent.

	Borrowed, never owned: this object does not create, clear or reset a store, and unbinding
	drops its references without touching a column.
	"""
	if residents == null or transforms == null:
		return _refuse(REFUSE_NOT_BOUND)
	_residents = residents
	_transforms = transforms
	_last_refusal = REFUSE_NONE
	return true


func unbind_stores() -> void:
	"""Drop both borrowed readers and stop drawing, without writing to either store."""
	_residents = null
	_transforms = null
	_drawn_count = 0
	_skipped_unplaced = 0
	multimesh.visible_instance_count = 0


func transforms() -> TransformsScript:
	"""The BORROWED pose store this crowd reads, or null while unbound.

	Exists so a test can prove the renderer reads the SETTLEMENT's store by identity rather than
	by comparing coordinates two stores might coincidentally share.
	"""
	return _transforms


func is_bound() -> bool:
	"""True when both readers are present and a refresh can run."""
	return _residents != null and _transforms != null


func set_crowd_mesh(mesh: Mesh) -> bool:
	"""Adopt the one mesh every instance draws. Refuses null rather than drawing nothing silently."""
	if mesh == null:
		return _refuse(REFUSE_NO_MESH)
	multimesh.mesh = mesh
	_last_refusal = REFUSE_NONE
	return true


func has_crowd_mesh() -> bool:
	"""True once a mesh has been adopted; a crowd without one occupies no pixels."""
	return multimesh.mesh != null


# --- the per-frame refresh --------------------------------------------------------------------

func refresh_into(alpha_numerator: int, alpha_denominator: int, out: IntMath.IntResult) -> bool:
	"""Redraw every LIVING resident at `alpha_numerator/alpha_denominator` between two ticks.

	`out` carries the number of instances actually drawn. It is caller-owned so that a render
	frame allocates nothing; the caller keeps one and passes it every frame. Refuses when a store
	is missing or the alpha is not a fraction in 0..1, because drawing zero residents and refusing
	to draw are different answers and a returned 0 would conflate them.
	"""
	if not is_bound():
		return out.refuse(String(_refused(REFUSE_NOT_BOUND)))
	if alpha_denominator <= 0 or alpha_numerator < 0 or alpha_numerator > alpha_denominator:
		return out.refuse(String(_refused(REFUSE_INVALID_ALPHA)))
	_drawn_count = 0
	_skipped_unplaced = 0
	for slot: int in INSTANCE_CAPACITY:
		if not _residents.is_alive(slot):
			continue
		if not _transforms.presentation_interpolate_into(
				_residents.ref_of(slot), alpha_numerator, alpha_denominator, _pose):
			_skipped_unplaced += 1
			continue
		_write_instance(_drawn_count, slot)
		_drawn_count += 1
	_publish()
	_last_refusal = REFUSE_NONE
	return out.succeed(_drawn_count)


func _write_instance(instance: int, slot: int) -> void:
	"""Write ONE resident's interpolated origin into its instance and record whose it is.

	The basis stays as `_reset_buffer()` left it: identity. See the header on why the interpolated
	yaw in `_pose` is read and discarded rather than turned into a rotation.
	"""
	var base: int = instance * FLOATS_PER_INSTANCE
	_buffer[base + OFFSET_ORIGIN_X] = _pose.x_metres
	_buffer[base + OFFSET_ORIGIN_Y] = _pose.y_metres
	_buffer[base + OFFSET_ORIGIN_Z] = _pose.z_metres
	_instance_slot[instance] = slot


func _publish() -> void:
	"""Hand the whole preallocated buffer to the server and show exactly the drawn instances.

	Instances at or above `_drawn_count` keep whatever they last held; `visible_instance_count`
	is what stops them being drawn, so a settlement that loses a resident loses an instance on
	the same frame without the buffer being cleared or resized.
	"""
	multimesh.buffer = _buffer
	multimesh.visible_instance_count = _drawn_count


# --- readers ------------------------------------------------------------------------------------

func drawn_count() -> int:
	"""Instances the most recent successful refresh drew. Zero before the first one."""
	return _drawn_count


func skipped_unplaced_count() -> int:
	"""Living residents the most recent refresh could not draw because no pose is placed for them.

	Reported rather than swallowed: a settlement whose residents have no Transform row is a
	blocked composition, not an empty crowd, and the two look identical on screen.
	"""
	return _skipped_unplaced


func visible_instance_count() -> int:
	"""What the MultiMesh itself will draw, read back from the resource rather than from a copy."""
	return multimesh.visible_instance_count


func slot_at_instance(instance: int, out: IntMath.IntResult) -> bool:
	"""Which resident row an instance carries, or a refusal for an index outside the buffer.

	Refuses rather than answering NO_SLOT for an out-of-range index: "instance 900 does not exist"
	and "instance 5 is not currently drawn" are different facts and share no answer.
	"""
	if instance < 0 or instance >= INSTANCE_CAPACITY:
		return out.refuse(String(REFUSE_INVALID_INSTANCE))
	return out.succeed(_instance_slot[instance])


func instance_origin(instance: int) -> Vector3:
	"""The drawn origin of one instance, in metres. Presentation only; see the header."""
	if instance < 0 or instance >= INSTANCE_CAPACITY:
		return Vector3.ZERO
	var base: int = instance * FLOATS_PER_INSTANCE
	return Vector3(_buffer[base + OFFSET_ORIGIN_X], _buffer[base + OFFSET_ORIGIN_Y],
		_buffer[base + OFFSET_ORIGIN_Z])


func instance_basis(instance: int) -> Basis:
	"""The drawn basis of one instance. IDENTITY for every instance; see the header on facing.

	Read from the buffer rather than from a constant, so the day a yaw convention is settled this
	reader reports what is actually drawn and a test can hold it to it.
	"""
	if instance < 0 or instance >= INSTANCE_CAPACITY:
		return Basis.IDENTITY
	var base: int = instance * FLOATS_PER_INSTANCE
	return Basis(
		Vector3(_buffer[base + 0], _buffer[base + 4], _buffer[base + 8]),
		Vector3(_buffer[base + 1], _buffer[base + 5], _buffer[base + 9]),
		Vector3(_buffer[base + 2], _buffer[base + 6], _buffer[base + 10]))


func buffer_bytes() -> int:
	"""Exact mutable bytes this crowd owns, for the ARCH-MEM ledger row it is budgeted in."""
	return INSTANCE_CAPACITY * FLOATS_PER_INSTANCE * 4 + INSTANCE_CAPACITY * 4


func last_refusal() -> StringName:
	"""Reason the most recent refused call refused; empty after a successful one."""
	return _last_refusal


func _refuse(code: StringName) -> bool:
	"""Record a refusal code and return false, so callers can `return _refuse(...)`."""
	_last_refusal = code
	return false


func _refused(code: StringName) -> StringName:
	"""Record a refusal code and hand it straight back, for callers that refuse through `out`."""
	_last_refusal = code
	return code
